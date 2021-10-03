require 'telegram/bot'
require 'sequel'
require 'down'
require 'FileUtils'

###############################
# LIST OF COMMAND IDENTIFIERS #
START = '/start'
HELP = '/hilfe'
COUNT = '/anzahl'
REPORT = '/meldung'
ALL = '/all'
LAST = '/letzte'
FEEDBACK = '/feedback'
INLINE_REPORT = '/meldeform'
###############################
# TODO: Put into Hash map in different File

class Registerbot
    def initialize(bot_token, report_db, image_path)
        @token = bot_token
        @reports = report_db
        @images = image_path
        Telegram::Bot::Client::run(@token) do |reg_bot|
            @bot = reg_bot
        end
    end
    
    def reply(text)
        @bot.api.send_message(chat_id: @message.chat.id, text: text, reply_to_message: @message)    
    end

    def send_message(text)
        @bot.api.send_message(chat_id: @message.chat.id, text: text)    
    end

    # Return the Reports of the last 'd' Days from the Dataset
    def get_last_days(days)
        now = Time.now
        @reports.select(:id, :activity).order(:id).where{timestamp > (now - (2592000 * days)).to_f}.all
    end

    # Method to turn the Array of Hashes from the Dataset into a String with Delimiters between Reports
    def format_results(res)
        reports = []
        res.each { |report|
            reports << "Meldung Nummer #{report[:id]}: #{report[:activity].inspect}"
        }
        reports.join("\n--------\n")
    end

    def start
        send_message("Hallo #{@message.from.first_name}! Ich bin ein Bot für Meldungen rechter Aktivitäten in Berlin Charlottenburg-Wilmersdorf. Wenn du mehr über das Register erfahren möchtest, dann schau doch mal auf die Website: https://berliner-register.de/charlottenburg-wilmersdorf.\n\nBei mir kannst du ganz einfach per Telegram-Nachricht Meldungen durchgeben, ohne erst viel auf Websiten oder E-Mails rumsuchen zu müssen. Probier doch glech einmal den /hilfe Befehl, um zu sehen, was ich alles kann.\n\nHinweis: Ich bin kein offizielles Produkt des Berliner Registers, sondern ein privates Projekt zur Unterstützung desselben. Ich befinde mich aktuell noch sehr am Anfang meiner Entwicklung, also entschuldige bitte den kleinen Funktionsumfang und einzelne Bugs.")
    end

    def help
        send_message("Folgende Befehle kannst du aktuell benutzen:\n\n#{START}: Zeigt die Begrüßungsnachricht an.\n\n#{HELP}: Zeigt alle Verfügbaren Befehle an.\n\n#{COUNT}: Zeigt die Gesamtzahl der beim Bot eingegangenen Meldungen an.\n\n#{ALL}: Gibt ALLE eingegangenen Meldungen aus (Leider noch unformatiert und schlecht lesbar)\n\n#{REPORT} <Meldung>: Gib uns eine neue Meldung an, am besten in folgendem Format: <Datum des Geschehens/der Entdeckung> <Ort> <Geschehnis/Entdeckung> <Kontaktmöglichkeit für Rückfragen(optional)>. Du kannst auch mehrere Meldungen auf einmal abgeben, indem du diese mit dem Prozentzeichen '%' trennst.\n\n#{LAST} <(optional) Tage>: Gibt die Meldungen der letzten 7 Tage aus. Du kannst selber eine Anzahl an Tagen angeben, von denen du die Meldungen sehen möchtest.")
    end

    def report(args)
        if args.count < 2
            reply("Du hast mir leider keine Meldung mitgeteilt. Bitte schreibe nach dem '/meldung' ein paar Worte.")
        else
            if @message.photo != []
                image = @bot.api.get_file(file_id: @message.photo[1].file_id)
                image_temp = Down.download("https://api.telegram.org/file/bot#{@token}/#{image["result"]["file_path"]}", destination: "#{@images}/#{@message.photo[1].file_unique_id}.jpg")
            end
            act = args[1..-1].join(' ')
            act = act.split("%")
            act.each { |report|
                @reports.insert(:activity => report.strip(), :timestamp => Time.now.to_f) 
            }
            if act.count > 1
               reply("Ich habe deine Meldungen zur Datenbank hinzugefügt. Danke für deine Mithilfe")
            else
                reply("Ich habe deine Meldung #{act[0].inspect} zur Datenbank hinzugefügt. Danke für deine Mitarbeit.")
            end
        end
    end

    def count
        reply("Anzahl bisheriger Meldungen: #{@reports.count}")
    end

    def all
        res = @reports.all
        reply("Übersicht über alle bisherigen Meldungen:\n\n#{format_results(res)}")
    end

    def last(args)
        if args.count < 2
            send_message("Die Meldungen der letzten 7 Tage lauten:\n\n#{format_results(get_last_days(7))}")
        else
            begin
                d = Integer(args[1])
            rescue
                reply("Du hast keine valide Zahl angegeben, bitte versuche es noch einmal.")
            else
                if d <= 0
                    reply("Bitte gib eine Zahl größer als 0 an.")
                else
                    send_message("Die Meldungen der letzten #{d} Tage lauten:\n\n#{format_results(get_last_days(d))}")
                end
            end
        end
    end

    def feedback
        rating = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard:[%w(1 2 3 4 5)], one_time_keyboard: true, resize_keyboard: true)
        @bot.api.send_message(chat_id: @message.chat.id, text:"Auf einer Skala von 1 (sehr schlecht) bis 5 (sehr gut), wie gefalle ich dir?", reply_markup: rating)
    end

    def bot_loop
        @bot.listen do |new_message|
            @message = new_message
            text = ""
            if @message.text != nil
                text = @message.text
            elsif @message.caption != nil
                text = @message.caption
            end
            args = text.split(' ')
            case args[0]
            when START # START Command, start conversation, opens greeting message
                start()
            when HELP # HELP Command, Display all possible Commands
                help()
            when REPORT # REPORT Command, file a new Report and put it into the Database
                report(args)
            when COUNT # COUNT Command, Print the Number of filed Reports
                count()
            when ALL # ALL Command, Print all filed Reports
                all()
            when LAST # LAST Command, Print all filed Reports from the last 7 (or 'd', if specified) days
                last(args)
            when FEEDBACK
                feedback()
            end
        end
    end     
end
