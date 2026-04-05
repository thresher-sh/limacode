# limacode
Claude Code, Codex, PI, Open Code - In a sandbox in one command.


Shell based app that wraps lima vm cli for fast startup of claude code and similar agents within a true VM. This allows them to have full capabilities like using docker etc, while having true kernel level isolation from the host machine.

By default limacode mounts the current directory at `~/workspace/current` within the vm and starts your desired agent from that directory.

Some additional options supported at this time, others to be added as folks request, are as follows:

- add additional directors to the vm under workspace with the following format `--adir <name>:<path>` ... `--adir github:~/github` would mount this as `~/workspace/github` in the vm. This allows you to bring additional code bases etc into the env. Note `current` name cannot be used as it is reserved for active command. You can do a comma separated list of names:path tuples to add multiple directories.
- you can change the agent to one of the supported agents by using `--agent <name>` for example `--agent codex`.
- you can restrict the internet access to a specific set of IP's or dns by adding `--restrict-dns <comma separated list>` for example `--restrict-dns api.github.com,registry.npm.com,127.0.0.1`
- you can build your own image vs using the hosted one by running `limacode build` and you can pass your own base image and provision script with the correct params `limacode build --image <name> --provision-script <path-to-provision-shell-script>`.

We will build and host images on our github releases for your quick use, as provisioning can take 5-10 minutes to build. If you just run `limacode build` it will use the built in `provision.sh` shipped with limacode.


> You can also access the shell environment of your running limacode anytime by doing `limacode shell` and if you have an active instance it will open it via shell. You can have multiple limacode sessions running, so if you run limacode shell when running multiple instances it will list your sessions to pick from.

## Global config

All of the options above such as additional directories and dns and agent choice can be configure globally for reuse and reduce param fatique.

```
limacode config agent <name>
limacode config restrict-dns <list>
limacode config adir <list>
limacode config provision-script <path>
limacode config image <name>
```

## Alias

Setup multiple alias if you want to use it with multiple agents quickly.

For example in your `.zshrc` file you could put:

```sh
alias cc=limacode --agent claudecode --adir "~/github"
alias codex=limacode --agent codex
alias claw=limacode --agent openclaw --adir "~/claw"
```


## Supports

mac and linux