#  EZ-Zim v0.3 Introduction
ez-zim is a lightweight Bash wrapper for OpenZIM's ZImit Crawler that simplifies creating offline ZIM archives of websites.
Instead of remembering the full docker syntax for invocation,volume mounts, Zimit arguments, and Kiwix refresh process, ez-zim reduces the workflow to:

zim -worker# -URL 

in the cli

## Why use EZ-Zimit??
Zimit already provides the required machinery to crawl modern websites and package them as zim files, however I have found that it is a pain to remember and having to type in all the implementation details each time.
this program just adds convenience and orchestration layer around that. 

EZ-Zim makes grabbing a zim archive of a website a simple command, while adding it to your desired final library and added convince that you don't get with the basic command.

It does not implement its own crawler or ZIM writer. Instead, it provides a small interface around existing tools:
- **Zimit** - crawls the website and produces the ZIM archive
- **Docker** - provides Zimit's runtime environment
- **Kiwix** - Optionally serves as the final destination


## Usage and syntax
There are custom arguments that I built into the cli so that you have the controls that actually matter, although if you do not care, I have kept the syntax sparse.

The current version:
1. Accepts a Website URL.
2. Generates a filesystem-safe name from the URL
3. Starts the official Zimit Docker image
4. Supplies the URL as the Zimit crawl seed
5. Runs the crawl with specified number of workers.
6. Writes the resulting Zim to the configured directory.
7. Restarts the directory


### Basic usage

zim <URL>

EZ-Zimit uses one worker by default.

Example:
zim https://example.com/

### Workers

To specify the number of crawl workers, use `-N`, where `N` is the number of workers:

zim -N <URL>

For example, to use four workers:

zim -4 https://example.com/

### Help
Use:

<zim --help> or <zim -h>

## Default Behavior
Running:
zim https://example.com/
will:
- Use `1` crawl worker.
- Store temporary crawl data in `~/.cache/ez-zimit`.
- Save the completed ZIM to `~/Downloads`.
- Resume an interrupted crawl when the same command is run again.
- Use a detected Kiwix installation at `/storage/kiwix` instead of `~/Downloads`.
- Restart the detected Kiwix container after a successful crawl.

## Configuration

EZ-Zimit can also be configured with environment variables.
| Variable | Purpose | Default |
| --- | --- | --- |
| `ZIM_OUTPUT_DIR` | Override the output directory | `~/Downloads` |
| `ZIM_BUILD_ROOT` | Override the build/cache directory | `~/.cache/ez-zimit` |
| `KIWIX_CONTAINER` | Kiwix Docker container name | `kiwix-serve` |
| `ZIMIT_IMAGE` | Zimit
Example:
ZIM_OUTPUT_DIR="$HOME/ZIMs" zim https://example.com/


## Requirements 
- Linux
- Bash
- Docker 
- Python 3
- Internet access for crawl


## Installation Guide 
### Installation is easy!
#### Run these Commands in order
1. git clone https://github.com/Joerichards12/EZ-Zimit.git
2. cd EZ-Zimit
3. chmod +x zim.sh
4. mkdir -p ~/.local/bin
5. ln -s "$(pwd)/zim.sh" ~/.local/bin/zim

## why I made the lil script 

this program was originally developed for my secondary experimental travel server, running a self hosted Kiwix server in docker compose on OpenMediaVault 8. 
I love how old games used to come out with strategy guides that gave you almost inside knowledge on where things were in a game. as a kid I remember using my copy of a Super Mario Bros DS guide to find things that I never would have otherwise. This script started as an easy way for me to grab strategy guides and preserve the entire structure and corpus that some of these detailed sites contain.

This solves a very small thing that many people wont care to fix, or even think is a problem, but I really like the idea of having anything online - offline through kiwix and zim archives. 