import
    std/[times],
    ../../updater/updater

discard """ """

assert getChannels(parse("2100-04-01", "yyyy-MM-dd")) == @[
    "https://channels.nixos.org/nixos-unstable",
    "https://channels.nixos.org/nixos-99.05",
    "https://channels.nixos.org/nixos-99.11",
    "https://channels.nixos.org/nixos-unstable-small",
    "https://channels.nixos.org/nixos-99.05-small",
    "https://channels.nixos.org/nixos-99.11-small"
    ]
assert getChannels(parse("2100-05-01", "yyyy-MM-dd")) == @[
    "https://channels.nixos.org/nixos-unstable",
    "https://channels.nixos.org/nixos-99.05",
    "https://channels.nixos.org/nixos-99.11",
    "https://channels.nixos.org/nixos-unstable-small",
    "https://channels.nixos.org/nixos-99.05-small",
    "https://channels.nixos.org/nixos-99.11-small"
    ]
assert getChannels(parse("2100-06-01", "yyyy-MM-dd")) == @[
    "https://channels.nixos.org/nixos-unstable",
    "https://channels.nixos.org/nixos-99.11",
    "https://channels.nixos.org/nixos-00.05",
    "https://channels.nixos.org/nixos-unstable-small",
    "https://channels.nixos.org/nixos-99.11-small",
    "https://channels.nixos.org/nixos-00.05-small"
    ]
assert getChannels(parse("2100-10-01", "yyyy-MM-dd")) == @[
    "https://channels.nixos.org/nixos-unstable",
    "https://channels.nixos.org/nixos-99.11",
    "https://channels.nixos.org/nixos-00.05",
    "https://channels.nixos.org/nixos-unstable-small",
    "https://channels.nixos.org/nixos-99.11-small",
    "https://channels.nixos.org/nixos-00.05-small"
    ]
assert getChannels(parse("2100-11-01", "yyyy-MM-dd")) == @[
    "https://channels.nixos.org/nixos-unstable",
    "https://channels.nixos.org/nixos-00.05",
    "https://channels.nixos.org/nixos-00.11",
    "https://channels.nixos.org/nixos-unstable-small",
    "https://channels.nixos.org/nixos-00.05-small",
    "https://channels.nixos.org/nixos-00.11-small"
    ]
assert getChannels(parse("2100-12-01", "yyyy-MM-dd")) == @[
    "https://channels.nixos.org/nixos-unstable",
    "https://channels.nixos.org/nixos-00.05",
    "https://channels.nixos.org/nixos-00.11",
    "https://channels.nixos.org/nixos-unstable-small",
    "https://channels.nixos.org/nixos-00.05-small",
    "https://channels.nixos.org/nixos-00.11-small"
    ]
