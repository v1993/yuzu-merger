# yuzu-merger - apply mainline and early access patches on top of main yuzu repo

I've made this tool mainly for myself, but still sharing it in case someone else finds it useful. I might consider making a bundle for non-Lua-snobs later.
This is a Lua script that makes keeping Yuzu git so much easier.

Please, don't report issues if you can't setup required environment for script (script doesn't go far enough to prompt you for mainline patches).

**If you are using Early Access patches, please consider supporting Yuzu team on [Patreon](https://patreon.com/yuzuteam) as well!**

## Dependencies

* Lua 5.3. May work with other versions, but not tested.
* Git, obviously.
* Following Luarocks:
* * [`luajson`](https://github.com/harningt/luajson) (available as `lua-json` package on Ubuntu)
  * `posix`
  * `luaossl` + `luasocket` (first depends on later)



## Usage

Setup repo like this:

```bash
git clone https://github.com/yuzu-emu/yuzu --recursive --depth=1000
cd yuzu
```

**Important: too low depth (especially `--depth=1`) will prevent utility from functioning with error from git about unrelated histories. Too large might cause slowdown and errors during cloning. `1000` seems like a good compromise.**

Then, every time you want to update and apply patches (including right after setup):

```bash
(inside yuzu directory)
lua patch/to/yuzu-merger.lua
```

Script will reset local changes, pull updates from master, then prompt you to choose merging of mainline and early access patches.
