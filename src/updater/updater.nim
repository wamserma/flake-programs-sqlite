# Copyright 2022 Markus S. Wamser
# SPDX: MIT

import std/[json, os, parseopt, re, sequtils, strformat, strutils, tempfiles, times, xmltree]

import osproc, streams

import httpClient
import q

const
  channelBaseUrl = "https://channels.nixos.org/nixos-"
  releaseBaseUrl = "https://releases.nixos.org"
  jsonFile = "sources.json"
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


proc getChannels*(now: DateTime): seq[string] =
  # get the current and previous release plus unstable
  var
    chans: seq[string] = @["unstable"]
    chanURLs: seq[string] = @[]

  let
    y = int(now.year) %% 100
    ly = (int(now.year)-1) %% 100
    m = int(now.month)

  if 5 < m and m < 11:
    chans.add(@[fmt"{ly:02}.11", fmt"{y:02}.05"])
  if  m <= 5:
    chans.add(@[fmt"{ly:02}.05", fmt"{ly:02}.11"])
  if m >= 11:
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

proc fetchFile(channelUrl: string): string =
  var
    client = newHttpClient()
  return client.getContent(channelUrl)

proc getMetadata*(htmlRaw: string): SqliteInfo =
  # scrape the data from the website ans build an SqliteInfo object
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

proc getHashfromNixexprs(info: SqliteInfo): SqliteInfo =
  let nixexprs = fetchFile(releaseBaseUrl & info.url)
  var updatedInfo = info
  if printDebugInfo: echo "Fetching " & releaseBaseUrl & info.url
  updatedInfo.hash = extractProgramsSqliteHash(nixexprs)
  if printDebugInfo: echo "\\-> hash of programs.sqlite:" & updatedInfo.hash
  return updatedInfo

proc writeHelp() = echo "Run as: updater --dir:path-to-json"
proc writeVersion() = echo "updater, v.0.1.0"

when isMainModule:
  var
    positionalArgs = newSeq[string]()
    directories = newSeq[string]()
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
    of cmdEnd: assert(false) # cannot happen

  if len(directories) > 1:
    echo "Only one dir argument allowed, ignoring all but first."
  if len(directories) < 1:
    directories.add(".")
  var jsonPath = directories[0]
  normalizePathEnd(jsonPath, trailingSep = true)

  let
    channels = getChannels(now().utc).mapIt(fetchFile(it)).mapIt(getMetadata(it))
    sourcesJson = parseFile(jsonPath & jsonFile)

  var
    queuedInfos: seq[SqliteInfo] = @[]
    queuedRevs: seq[string] = @[]

  for c in channels:
    if sourcesJson{c.rev} == nil and c.rev notin queuedRevs:
      queuedInfos.add(c)
      queuedRevs.add(c.rev)

  let newInfos = queuedInfos.mapIt(getHashfromNixexprs(it)).filterIt(len(it.hash) == 64 and match(it.hash, re"^[A-Fa-f\d]{64}$"))
  for c in newInfos:
    sourcesJson[c.rev] = %* {"name": c.name, "url": c.url, "nixexprs_hash": c.nixexprs_hash, "programs_sqlite_hash": c.hash}

  writeFile(jsonPath & jsonFile, pretty(sourcesJson))
