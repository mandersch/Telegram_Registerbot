require './lib/registerbot/basic_processor'
require './lib/registerbot/commands'
require 'telegram/bot'

# A Processor for `message`s that are only for user aid and to not require any knowledge of the `feedback` or `report` database.
#   Inherits from `Basic_processor` class (see #Basic_processor)
class Help_processor < Basic_processor
    
    # Is called when the user first interacts with the bot and is automatically sending the '/start' command
    #
    # @param message [Telegram::Bot::Types::Message] the original message received by the bot, used to identify the correct `chat_id` to respond to
    def start(message)
        send_message("Hallo #{message.from.first_name}! Ich bin ein Bot für Meldungen rechter Aktivitäten in Berlin Charlottenburg-Wilmersdorf. Wenn du mehr über das Register erfahren möchtest, dann schau doch mal auf die Website: https://berliner-register.de/charlottenburg-wilmersdorf.\n\nBei mir kannst du ganz einfach per Telegram-Nachricht Meldungen durchgeben, ohne erst viel auf Websiten oder E-Mails rumsuchen zu müssen. Probier doch glech einmal den /hilfe Befehl, um zu sehen, was ich alles kann.\n\nHinweis: Ich bin kein offizielles Produkt des Berliner Registers, sondern ein privates Projekt zur Unterstützung desselben. Ich befinde mich aktuell noch sehr am Anfang meiner Entwicklung, also entschuldige bitte den kleinen Funktionsumfang und einzelne Bugs.", message)
    end

    # Is called when the user sends the '/hilfe' command, displays all available commands to the user
    #
    # @param message [Telegram::Bot::Types::Message] the original message received by the bot, used to identify the correct `chat_id` to respond to
    def help(message)
        send_message("Folgende Befehle kannst du aktuell benutzen:\n\n#{START}: Zeigt die Begrüßungsnachricht an.\n\n#{HELP}: Zeigt alle Verfügbaren Befehle an.\n\n#{FORMULAR_REPORT}: Ein Step-by-Step Formular, um super einfach Meldungen zu machen, ohne etwas zu vergessen.\n\n#{REPORT} <Meldung(en)>: Gib mir neue Meldungen an. Verwende dabei folgendes Format: <Datum>; <Ort>; <Beobachtung>(ab hier ist alles optional); <Kontakt für Nachfragen> % <nächste Meldung>. Da das Format unübersichtlich und Tippfehleranfällig ist empfehle ich dir lieber das Meldeformular zu nutzen, dort kannst du mir auch Fotos schicken.\n\n#{ALL}: Gibt alle eingegangenen Meldungen aus.\n\n#{COUNT}: Gibt die Gesamtanzahl der bei mir eingegangenen meldungen aus.\n\n#{LAST} <(optional) Tage>: Gibt die Meldungen der letzten 7 Tage aus. Du kannst selber eine Anzahl an Tagen angeben, von denen du die Meldungen sehen möchtest.\n\n#{FEEDBACK}: Gib mir Feedback :) Bewerte mich zuerst auf einer Skala von 1-5 und dann kannst du mir auch noch Tipps geben!", message)
    end

    # Is called when the User Input does not match any known command or step in feedback or reporting
    #
    # @param message [Telegram::Bot::Types::Message] the original message received by the bot, used to identify the correct `chat_id` to respond to
    def unknown(message)
        send_message("Sorry, ich weiß nicht was du mir sagen möchtest. Probier doch mal #{HELP}, um zu sehen was ich kann.", message)
    end
end