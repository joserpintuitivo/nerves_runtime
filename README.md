# Nerves.Runtime

[![Build Status](https://travis-ci.org/nerves-project/nerves_runtime.svg)](https://travis-ci.org/nerves-project/nerves_runtime.svg)
[![Hex version](https://img.shields.io/hexpm/v/nerves_runtime.svg "Hex version")](https://hex.pm/packages/nerves_runtime)

Nerves.Runtime is a core component of Nerves. It contains applications and
libraries that are expected to be useful on all Nerves devices.  Here are some
of its features:

* Generic system and filesystem initialization (suitable for use with
  [bootloader](https://github.com/nerves-project/bootloader)
* Introspection of Nerves system firmware and deployment metadata
* A custom shell for debugging and running commands in a `bash` shell like
  environment
* A small Linux kernel `uevent` application for capturing hardware change events
  and more
* More to come...

The following sections describe the features in more detail. For even more
information, consult the [hex docs](https://hexdocs.pm/nerves_runtime).

## System initialization

Nerves.Runtime provides an OTP application that can initialize the system when
it is started. For this to be useful, Nerves.Runtime must be started before
other OTP applications especially since non-Nerves-aware applications almost
certainly won't know that they need this to work. Specific initialization is
detailed in other sections. To set Nerves.Runtime up with `bootloader`, you will
need to do the following (luckily this should become easier as this new
functionality propagates through templates and examples.)

1. Ensure that `bootloader` is included in your `mix.exs` and the
   `Bootloader.Plugin` is in your `rel/config.exs`.
2. In your `config/config.exs`, make sure that `:nerves_runtime` is at the
   beginning of the `init:` list:
```
config :bootloader,
  overlay_path: "",
  init: [:nerves_runtime, :other_app],
  app: :your_app
```

## Filesystem initialization

Nerves systems generally ship with one or more application filesystem
partitions. These are used for persisting data that's expected to live between
firmware updates. The root filesystem cannot be used since it is mounted
read-only in Nerves.

Nerves.Runtime takes an unforgiving approach to managing the application
partition: if it can't be mounted read-write, it gets re-formatted. While
filesystem corruption should be a rare event even on unexpected powerdowns with
modern filesystems, Nerves devices may not be easily accessed to perform any
kind of recovery. This allows for at least some functionality.

To verify that this recovery works, Nerves systems usually leave the application
filesystems uninitialized so that the format operation happens on the first
boot. This means that the first boot takes slightly longer than others.

Note that a common implementation of "reset to factory" defaults is to
purposefully corrupt the application partition and reboot.

Nerves.Runtime uses firmware metadata to determine how to mount and initialize
the application partition. The following variables are important:

* `[partition].nerves_fw_application_part0_devpath` - the path to the
  application partition. E.g., `/dev/mmcblk0p3`
* `[partition].nerves_fw_application_part0_fstype` - the type of filesystem.
  E.g., `ext4`
* `[partition].nerves_fw_application_part0_target` - where the partition should
  be mounted. E.g., `/root` or `/mnt/appdata`

## Nerves system and firmware metadata

All official Nerves systems maintain a short list of key-value pairs for
tracking the running firmware version, etc. and other system information. This
information is not intended to be written frequently. To get this information,
call one of the following:

* `Nerves.Runtime.KV.get_all_active/0` - return all key-value pairs associated
  with the actively running firmware.
* `Nerves.Runtime.KV.get_active/0` - return all key-value pairs. This includes
  key-value pairs associated with the non-running firmware in an A/B partitioned
  system.
* `Nerves.Runtime.KV.get_active/1` - look up the value of a key associated with
  the currently running firmware.
* `Nerves.Runtime.KV.get/1` - look up the value of a key

## The Nerves Runtime Shell

Nerves devices typically only expose an Elixir or Erlang shell prompt. While
this is handy, some tasks are quicker to run in a more `bash` shell-like
environment. The Nerves runtime shell provides a limited approximation to this
that can be run without leaving the Erlang runtime. Here's an example run:

```
iex(1)> [Ctrl+G]
User switch command
 --> s sh
 --> j
   1  {erlang,apply,[#Fun<Elixir.IEx.CLI.1.112225073>,[]]}
   2* {sh,start,[]}
 --> c
Nerves Interactive Command Shell

Type Ctrl+G to exit the shell and return to Erlang job control.
This is not a normal shell, so try not to type Ctrl+C.

/srv/erlang[1]>
```

There are a few caveats to using this shell right now, so you'll have to be
careful when you use it:

1. `Ctrl+C Ctrl+C` exits the Erlang VM and will reboot or hang your system
   depending on how `erlinit` is configured.
2. Because of the `Ctrl+C` caveat, you can't easily break out of long running
   programs. As a workaround, start another shell using `Ctrl+G` and `kill` the
   offending program.
3. Commands are run asynchronously. This is unexpected if you're used to a
   regular shell. For most commands, it's harmless. One side effect is that if a
   command changes the current directory, it could be that the prompt shows the
   wrong path.

## Installation

The package can be installed
by adding `nerves_runtime` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:nerves_runtime, "~> 0.2.0"}]
end
```

Docs can be found at [https://hexdocs.pm/nerves_runtime](https://hexdocs.pm/nerves_runtime).
