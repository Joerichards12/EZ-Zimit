#EZ-Zim
			

ez-zim is a lightweight Bash wrapper for OpenZIM's ZImit Crawler that simplifies creating offline ZIM archives of websites.
Instead of remembering the full docker syntax for invocation,volume mounts, Zimit arguments, and Kiwix refresh process, ez-zem reduces the workflow to:

zim -worker# -URL 

in the cli

##Why ez-zim
Zimit already provides the reuired machinery to crawl modern websites and package them as zim files, however I have found that it is a pain to remember and having to type in all the implementation details each time.
this program just adds convience and orchestration layer around that. 

EZ-Zim makes grabbing a zim archive of a website a simple command, while adding it to your desired final library and added conviences that you dont get with the basic command.

It does not implement its own crawler or ZIM writer. Instead, it provides a small interface around existing tools:
- **Zimit** - crawls the website and produces the ZIM archive
- **Docker** - provides Zimit;s runtime enviornment
- **Kiwix** - Optionally serves as the final destination

## Usage 

	zim <URL>

	example: zim https://example.com

The current version:
1. Acceps a Website URL 
2. Generates a filesystem-safe name from the URL
3. Starts the official Zimit Docker image
4. Supplies the URL as the Zimit crawl seed
5. Runs the crawl with specified number of workers.
6. Writes the resulting Zim to the configured directory.
7. Restarts the directory

## Reauirements 
-Linux
-Bash
-Docker
-Python 3
-Internet access for crawl
Kiwix is mainly for my usage so technically optional

##Installation 
Place the script somewhere in your PATH. for a system-wide installation:
	run;
		sudo cp zim.sh /usr/local/bin/zim
		sudo chmod +x /usr/local/bin/zim

It can then be called from any directory:

	zim <URL>


## why I made 

this program was originally developed for my secondary experimental travel server "atlas", running a self hosted Kiwix server in docker compose on OpenMediaVault 8. 

