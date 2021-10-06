require './lib/registerbot/basic_processor'
require './lib/registerbot/commands'
require 'telegram/bot'

class Help_processor < Basic_processor
    def start(message)
        send_message("Hallo #{message.from.first_name}! Ich bin ein Bot für Meldungen rechter Aktivitäten in Berlin Charlottenburg-Wilmersdorf. Wenn du mehr über das Register erfahren möchtest, dann schau doch mal auf die Website: https://berliner-register.de/charlottenburg-wilmersdorf.\n\nBei mir kannst du ganz einfach per Telegram-Nachricht Meldungen durchgeben, ohne erst viel auf Websiten oder E-Mails rumsuchen zu müssen. Probier doch glech einmal den /hilfe Befehl, um zu sehen, was ich alles kann.\n\nHinweis: Ich bin kein offizielles Produkt des Berliner Registers, sondern ein privates Projekt zur Unterstützung desselben. Ich befinde mich aktuell noch sehr am Anfang meiner Entwicklung, also entschuldige bitte den kleinen Funktionsumfang und einzelne Bugs.", message)
    end

    def help(message)
        send_message("Folgende Befehle kannst du aktuell benutzen:\n\n#{START}: Zeigt die Begrüßungsnachricht an.\n\n#{HELP}: Zeigt alle Verfügbaren Befehle an.\n\n#{COUNT}: Zeigt die Gesamtzahl der beim Bot eingegangenen Meldungen an.\n\n#{ALL}: Gibt ALLE eingegangenen Meldungen aus (Leider noch unformatiert und schlecht lesbar)\n\n#{REPORT} <Meldung>: Gib mir eine neue Meldung in folgendem Format an: <Datum des Geschehens/der Entdeckung>; <Ort>; <Geschehnis/Entdeckung>; <Kontaktmöglichkeit für Rückfragen(optional)>. Du kannst auch mehrere Meldungen auf einmal abgeben, indem du diese mit dem Prozentzeichen '%' trennst.\n\n#{FORMULAR_REPORT}: Ein Step-by-Step Formular, um super einfach Meldungen zu machen, ohne etwas zu vergessen\n\n#{LAST} <(optional) Tage>: Gibt die Meldungen der letzten 7 Tage aus. Du kannst selber eine Anzahl an Tagen angeben, von denen du die Meldungen sehen möchtest.\n\n#{FEEDBACK}: Gib mir Feedback :) Bewerte mich zuerst auf einer Skala von 1-5 und dann kannst du mir auch noch Tipps geben!", message)
    end

    def unknown(message)
        send_message("Sorry, ich weiß nicht was du mir sagen möchtest. Probier doch mal #{HELP}, um zu sehen was ich kann.", message)
    end
end