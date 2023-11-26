# Copyright 2022 Markus S. Wamser
# SPDX: MIT

import std/[json, logging, options, os, parseopt, re, sequtils, strformat, strutils, tempfiles, times, xmltree]

import osproc, streams

import httpClient
import q

const
  channelBaseUrl = "https://channels.nixos.org/nixos-"
  releaseBaseUrl = "https://releases.nixos.org"
  jsonFile = "sources.json"
  jsonFileLatest = "latest.json"
  systemXZ = "xz"
  systemTar = "tar"
  systemSha256 = "sha256sum"
  systemShell = "/bin/sh"
  printDebugInfo = false

type
  SqliteInfo* = object
    rev*: string  # git revision
    name*: string # name, e.g. nixos-22.11.740.7a6a010c3a1
    url*: string  # URL of nixexprs.tar.xz, e.g. /nixos/22.11-small/nixos-22.11.740.7a6a010c3a1/nixexprs.tar.xz
    nixexprs_hash*: string # SHA256 of nixexprs.tar.xz as given on webpage
    hash* : string # SHA256 of programs.sqlite

var
  logger = newConsoleLogger()

proc getChannels*(now: DateTime): seq[string] =
  # get the current and previous release plus unstable
  # also take care of the time window between branch-off and relase
  var
    chans: seq[string] = @["unstable"]
    chanURLs: seq[string] = @[]

  let
    y = int(now.year) %% 100
    ly = (int(now.year)-1) %% 100
    m = int(now.month)
    d = int(now.monthday)

  if m <= 5: # both releases from previous year
    chans.add(@[fmt"{ly:02}.05", fmt"{ly:02}.11"])
  if m == 5 and d > 21: # .05 branch off, but not yet released
    chans.add(@[fmt"{y:02}.05"])
  if 5 < m and m <= 11: # .05 from current year, .11 from previous year
    chans.add(@[fmt"{ly:02}.11", fmt"{y:02}.05"])
  if m == 11 and d > 21: # .11 branch off, but not yet released
    chans.add(@[fmt"{y:02}.11"])
  if m > 11: # both releases from current year
    chans.add(@[fmt"{y:02}.05", fmt"{y:02}.11"])
  for suffix in ["", "-small"]:
    for chan in chans:
      chanURLs.add(channelBaseUrl & chan & suffix)
  return chanURLs

proc stripTags(d: XmlNode): string =
  return ($d).multiReplace([(re"<[^>]*>", "")])

proc extractName(d: XmlNode): string =
  return d.stripTags().split()[2]

proc extractNixexpr(xml: seq[XmlNode]) : array[2, string] =
  let
    nixexprsRow = xml.filterIt("nixexprs.tar.xz" in $it)[0]
    url = nixexprsRow.select("a")[0].attr("href")
    hash = nixexprsRow.select("tt")[0].stripTags()
  return [url, hash]

proc fetchFile(channelUrl: string): Option[string] =
  var
    client = newHttpClient()
  try:
    return some(client.getContent(channelUrl))
  except HttpRequestError as hce:
    logger.log(lvlWarn, "Unable to fetch " & channelUrl & " (" & hce.msg & ")")
  finally:
    client.close()

proc getMetadata*(htmlRaw: string): SqliteInfo =
  # scrape the data from the website and build an SqliteInfo object
  var
    info: SqliteInfo

  let
    qHtmlRaw  = q(htmlRaw)
    uh = (qHtmlRaw.select("tr+td+a")).extractNixexpr()

  info.name = (qHtmlRaw.select("h1")[0]).extractName()
  info.rev = (qHtmlRaw.select("p+a+tt")[0]).select("tt")[0].stripTags()
  info.url = uh[0]
  info.nixexprs_hash = uh[1]
  info.hash = "" # getting this is expensive, fill on demand later
  return info

proc extractProgramsSqliteHash(tarball: string): string =
  let (cfile, path) = createTempFile("nixexpr_tgz_", "_end.tmp")
  cfile.write(tarball)
  close cfile
  let cmdLine = systemXZ & " --decompress --stdout " & path & " | " & systemTar & " -xf - "  & " --wildcards */programs.sqlite -O | " & systemSha256
  let pout = execProcess(command = systemShell, args = ["-c", cmdLine], options = {poUsePath, poStdErrToStdOut})
  if printDebugInfo: echo pout
  let hash = pout.split()[0]
  removeFile(path)

  return hash

proc getHashfromNixexprs(info: SqliteInfo): Option[SqliteInfo] =
  let nixexprs = fetchFile(releaseBaseUrl & info.url)
  if nixexprs.isNone:
    return none(SqliteInfo)
  var updatedInfo = info
  if printDebugInfo: echo "Fetching " & releaseBaseUrl & info.url
  updatedInfo.hash = extractProgramsSqliteHash(nixexprs.get())
  if printDebugInfo: echo "\\-> hash of programs.sqlite:" & updatedInfo.hash
  return some(updatedInfo)

proc writeHelp() =
    echo "Run as: updater --dir:path-to-json\n or as: updater --dir:path-to-json --channel:channel-revision"
    quit(QuitSuccess)
proc writeVersion() =
    echo "updater, v0.2.1"
    quit(QuitSuccess)

when isMainModule:
  var
    positionalArgs = newSeq[string]()
    directories = newSeq[string]()
    requestedChannels = newSeq[string]()
    optparser = initOptParser(quoteShellCommand(commandLineParams()))

  for kind, key, val in optparser.getopt():
    case kind
    of cmdArgument:
      discard
    of cmdLongOption, cmdShortOption:
      case key
      of "help", "h": writeHelp()
      of "version", "v": writeVersion()
      of "dir", "d":
        directories.add(val)
      of "channel", "c":
        requestedChannels.add(val)
    of cmdEnd: assert(false) # cannot happen

  if len(directories) > 1:
    echo "Only one dir argument allowed, ignoring all but first."
  if len(directories) < 1:
    directories.add(".")
  var jsonPath = directories[0]
  normalizePathEnd(jsonPath, trailingSep = true)

  if len(requestedChannels) < 1:
    requestedChannels.add(getChannels(now().utc))

  let
    channels = requestedChannels.mapIt(fetchFile(it)).filterIt(it.isSome).mapIt(getMetadata(it.get()))
    sourcesJson = parseFile(jsonPath & jsonFile)
    sourcesLatestJson = parseFile(jsonPath & jsonFileLatest)

  var
    queuedInfos: seq[SqliteInfo] = @[]
    queuedRevs: seq[string] = @[]

  for c in channels:
    if sourcesJson{c.rev} == nil and c.rev notin queuedRevs:
      queuedInfos.add(c)
      queuedRevs.add(c.rev)

  let newInfos = queuedInfos.mapIt(getHashfromNixexprs(it)).filterIt(it.isSome).mapIt(it.get()).filterIt(len(it.hash) == 64 and match(it.hash, re"^[A-Fa-f\d]{64}$"))
  for c in newInfos:
    sourcesJson[c.rev] = %* {"name": c.name, "url": c.url, "nixexprs_hash": c.nixexprs_hash, "programs_sqlite_hash": c.hash}
    let release = c.name[6..10] # extract release number from "nixos-YY.mmSUFFIX"
    sourcesLatestJson[release] = %* {"name": c.name, "url": c.url, "nixexprs_hash": c.nixexprs_hash, "programs_sqlite_hash": c.hash}

  writeFile(jsonPath & jsonFile, pretty(sourcesJson))
  writeFile(jsonPath & jsonFileLatest, pretty(sourcesLatestJson))
