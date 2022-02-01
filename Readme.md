# Telegram Registerbot

## Introduction

This is a Telegram-Bot for the "Berliner Register". If you don't know what the Register is, definitely check out [their website](https://www.berliner-register.de/). 
But in short: the Berliner Register aims to give a better track of right-wing activities in Berlin by asking people all around Berlin to contribute their sightings volountarily, since the official numbers are far below the actual case numbers.

The idea of this bot is to make it much easier to file reports to the Register collective, by making reports as simple as writing Short messages on your phone, which you can always do on the go and most importantly, you can now directly file reprts of things you spotted instead of having to write Mails (which is uncomfortable for a lot of people) or a letter/postcard.

## Set-Up

After cloning this Repo, make sure you have ruby installed and run
```bash
bundle
```
to fetch all the gems needed.

**IMPORTNAT NOTE:** If you are using windows, you need to have Ruby with the DevKit installed (found [here](https://rubyinstaller.org/downloads/)) to run `bot.rb` because of the SQLite3 Database used. However for serious usage of this product, it might be useful anyway to switch to a web-based Database and use that instead of the SQLite3 Database. Have a look at the Sequel gem documentation for further instruction on how to do this (it's quite simple, really).

Next thing you're going to need is a Telegram Bot Token. This can be easily acquired by following [this](https://core.telegram.org/bots#) tutorial and talking to the Botfather.
The `bot.rb` programm searches for a bot token stored in a file named `token.priv`, so make sure to create this file and copy your bot token into it.

The last thing you need to make sure is that the bot/Ruby has permission to create folders and files as this is necessary for stroing the Database and images right now.

After all that is done, you are clear to run the bot with
```bash
ruby bot.rb
```
which starts an instance of the bot on your PC with which all Telegram users can interact.

For the full bot documentation 

Currently, the bot is only available in german, as switching languages requires the bot to save chat/user-ids (to identify which language to use in which chat) which I did not want to do for any longer than necessary.

## Quick Overview

When run, the `bot.rb` script creates the necessary folders and checks for the key and then creates a new instance of the actual bot and starts it's listening loop.
The definition of this bot can be found in `registerbot.rb`. There you will find, that the bots consists of five main components: a `command_handler`, three processing units inside that very handler and a `bot`. 
The `bot` is the actual interface to the Telegram Bot API and is used for all communications with users on Telegram (e.g. listening for their messages, responding to messages).
The `Registerbot` instance runs the `bot_loop`, and the `command_handler` sorts incoming messages to each of the three processors: the `help_processor` deals with all messages reagarding questions to the bot, help messages etc. The `reports_processor` is the heart and soul of this bot, dealing with incoming reports or querys on the reports dataset. Lastly the `feedback_processor` deals with all the incoming feedback and stores it in a separate Database table.

Per default, the bot saves all its logs into a file located at './log/log.txt'. You can run 
```bash
tail -f log/log.txt
```
to view all status logs written to this file while running. (Might need to install tail on windows, have a look [here](https://www.technlg.net/windows/download-windows-resource-kit-tools/))

For a more detailed view on all the components, view the documentation of all this using `yard`, which should be installed alongside all other gems when running `bundle`. 
To do so simply run
```bash
yard server
```
which should print you a server address somewhat like `http://localhost:8808`. 
Use your favourite browser to open this URL and you should see the full documentation for this project.
However, if you are greeted by Error messages of missing gems, install them using the `gem` command and you should be golden.

## Further notes

This is not a product by the 'Berliner Register'-Team, not even one requested by them. I made this solely on my own out of pure interest.
The Team behind 'Berliner Register' is not responsible for any Presentations, Errors or Mishaps in this repository or the usage of this bot as of right now.
