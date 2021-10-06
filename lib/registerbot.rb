require 'telegram/bot'
require 'sequel'
require 'down'
require 'fileutils'
require 'logger'

###############################
# LIST OF COMMAND IDENTIFIERS #
START = '/start'
HELP = '/hilfe'
COUNT = '/anzahl'
REPORT = '/meldung'
ALL = '/all'
LAST = '/letzte'
FEEDBACK = '/feedback'
ALL_FEEDBACK = '/all_feedback'
FORMULAR_REPORT = '/meldeform'
CANCEL = '/cancel'
###############################
# TODO: Put into Hash map in different File

YES = "Ja"
NO = "Nein"

RATING = 1
ASKED_FOR_TIPS = 2
GIVING_TIPS = 3
REPORTING_DATE = 4
REPORTING_PLACE = 5
REPORTING_ACTIVITY = 6
ASKED_FOR_CONTACTS = 7
GIVING_CONTACTS = 8
ASKED_FOR_IMAGE = 9
GIVING_IMAGE = 10


class Registerbot
    Dummy = Struct.new(:state)
    Feedback_Inputs = Struct.new(:state, :rating, :tips)
    Report_Inputs = Struct.new(:state, :date, :place, :activity, :contacts, :image_path)
    logger = Logger.new(STDOUT)
    logger.level = Logger::DEBUG   
    def initialize(bot_token, report_db, feedback_db, image_path)
        @token = bot_token
        @reports = report_db
        @feedback = feedback_db
        @images = image_path
        @user_state = Hash.new
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

    def format_feedback(res)
        feedbacks = []
        res.each { |feedback|
            feedbacks << "Feedback Nummer #{feedback[:id]}: Bewertung: #{feedback[:rating].inspect}, Anmerkungen: #{feedback[:tips].inspect}"
        }
        feedbacks.join("\n--------\n")
    end

    def start
        send_message("Hallo #{@message.from.first_name}! Ich bin ein Bot für Meldungen rechter Aktivitäten in Berlin Charlottenburg-Wilmersdorf. Wenn du mehr über das Register erfahren möchtest, dann schau doch mal auf die Website: https://berliner-register.de/charlottenburg-wilmersdorf.\n\nBei mir kannst du ganz einfach per Telegram-Nachricht Meldungen durchgeben, ohne erst viel auf Websiten oder E-Mails rumsuchen zu müssen. Probier doch glech einmal den /hilfe Befehl, um zu sehen, was ich alles kann.\n\nHinweis: Ich bin kein offizielles Produkt des Berliner Registers, sondern ein privates Projekt zur Unterstützung desselben. Ich befinde mich aktuell noch sehr am Anfang meiner Entwicklung, also entschuldige bitte den kleinen Funktionsumfang und einzelne Bugs.")
    end

    def help
        send_message("Folgende Befehle kannst du aktuell benutzen:\n\n#{START}: Zeigt die Begrüßungsnachricht an.\n\n#{HELP}: Zeigt alle Verfügbaren Befehle an.\n\n#{COUNT}: Zeigt die Gesamtzahl der beim Bot eingegangenen Meldungen an.\n\n#{ALL}: Gibt ALLE eingegangenen Meldungen aus (Leider noch unformatiert und schlecht lesbar)\n\n#{REPORT} <Meldung>: Gib mir eine neue Meldung in folgendem Format an: <Datum des Geschehens/der Entdeckung>; <Ort>; <Geschehnis/Entdeckung>; <Kontaktmöglichkeit für Rückfragen(optional)>. Du kannst auch mehrere Meldungen auf einmal abgeben, indem du diese mit dem Prozentzeichen '%' trennst.\n\n#{LAST} <(optional) Tage>: Gibt die Meldungen der letzten 7 Tage aus. Du kannst selber eine Anzahl an Tagen angeben, von denen du die Meldungen sehen möchtest.\n\n#{FEEDBACK}: Gib mir Feedback :) Bewerte mich zuerst auf einer Skala von 1-5 und dann kannst du mir auch noch Tipps geben!")
    end

    def report(args) # TODO: refactor to make Report entry a bit more form like
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

    def form_report
        send_message("Okay, du kannst mir jetzt Schritt für Schritt die Daten einer Meldung durchgeben. Wenn du dich zwischendurch umentscheidest benutze #{CANCEL} um den Vorgang abzubrechen, dann lösche ich alle Teile der Meldung die du mir bisher gesagt hast.\nLass uns mit dem Datum anfangen; wann hast du etwas beobachtet?")
        @user_state[@message.chat.id] = Report_Inputs.new(REPORTING_DATE, nil, nil, nil, nil, nil)
    end

    def get_report_date(args)
        if args[0] == CANCEL
            send_message("Du hast den Vorgang abgebrochen. Ich lösche deine bisherigen Eingaben")
            @user_state.delete(@message.chat.id)
            return
        end
        @user_state[@message.chat.id] = Report_Inputs.new(REPORTING_PLACE, args.join(' '), nil, nil, nil, nil)
        send_message("Super! Als nächstes sag mir bitte, wo du etwas beobachtet hast.")
    end

    def get_report_place(args)
        if args[0] == CANCEL
            send_message("Du hast den Vorgang abgebrochen. Ich lösche deine bisherigen Eingaben")
            @user_state.delete(@message.chat.id)
            return
        end
        @user_state[@message.chat.id][:state] = REPORTING_ACTIVITY
        @user_state[@message.chat.id][:place] = args.join(' ')
        send_message("Gut, als nächstes das allerwichtigte: Was hast du beobachtet?")
    end

    def get_report_activity(args)
        if args[0] == CANCEL
            send_message("Du hast den Vorgang abgebrochen. Ich lösche deine bisherigen Eingaben")
            @user_state.delete(@message.chat.id)
            return
        end
        @user_state[@message.chat.id][:state] = ASKED_FOR_CONTACTS
        @user_state[@message.chat.id][:activity] = args.join(' ')
        decision = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard:[%w(Ja Nein)], resize_keyboard: true)
        @bot.api.send_message(chat_id: @message.chat.id, text:"Okay, das hätten wir. Möchtest du mir noch eine Kontaktmöglichkeit hinterlassen falls sich Rückfragen zu deiner Meldung ergeben?", reply_markup: decision)
    end

    def get_contact_decision(args)
        if args[0] == CANCEL
            send_message("Du hast den Vorgang abgebrochen. Ich lösche deine bisherigen Eingaben")
            @user_state.delete(@message.chat.id)
            return
        end
        hide = Telegram::Bot::Types::ReplyKeyboardRemove.new(remove_keyboard: true, selective: nil)
        case args[0]
        when YES
            @user_state[@message.chat.id][:state] = GIVING_CONTACTS
            @bot.api.send_message(chat_id: @message.chat.id, text:"Wie bist du zu erreichen? (E-Mail / Telefon / Telegram / oä)", reply_markup: hide)
        when NO
            @user_state[@message.chat.id][:contacts] = "Keine Kontaktmöglichkeit hinterlassen"
            @user_state[@message.chat.id][:state] = ASKED_FOR_IMAGE
            @bot.api.send_message(chat_id: @message.chat.id, text:"In Ordnung.", reply_markup: hide)
            decision = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard:[%w(Ja Nein)], resize_keyboard: true)
            @bot.api.send_message(chat_id: @message.chat.id, text:"Fast geschafft. Noch als letztes, möchtest du mir ein Foto von der Entdeckung schicken?", reply_markup: decision)
        end
    end

    def get_contact(args)
        if args[0] == CANCEL
            send_message("Du hast den Vorgang abgebrochen. Ich lösche deine bisherigen Eingaben")
            @user_state.delete(@message.chat.id)
            return
        end
        @user_state[@message.chat.id][:state] = ASKED_FOR_IMAGE
        @user_state[@message.chat.id][:contacts] = args.join(' ')
        decision = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard:[%w(Ja Nein)], resize_keyboard: true)
        @bot.api.send_message(chat_id: @message.chat.id, text:"Super, fast geschafft. Noch als letztes, möchtest du mir ein Foto von der Entdeckung schicken?", reply_markup: decision)
    end

    def get_image_decision(args)
        if args[0] == CANCEL
            send_message("Du hast den Vorgang abgebrochen. Ich lösche deine bisherigen Eingaben")
            @user_state.delete(@message.chat.id)
            return
        end
        hide = Telegram::Bot::Types::ReplyKeyboardRemove.new(remove_keyboard: true, selective: nil)
        case args[0]
        when YES
            @user_state[@message.chat.id][:state] = GIVING_IMAGE
            @bot.api.send_message(chat_id: @message.chat.id, text:"Super, dann schick mir doch bitte das Foto.", reply_markup: hide)
        when NO
            @bot.api.send_message(chat_id: @message.chat.id, text:"In Ordnung, ich habe deine Meldung der Datenbank hinzugefügt. Danke für deine Mitarbeit!", reply_markup: hide)
            @user_state[@message.chat.id][:image_path] = "Kein Bild angegeben."
            rep = @user_state[@message.chat.id]
            @reports.insert(:activity => "#{rep[:date]}: #{rep[:place]}: #{rep[:activity]}", :contact => "#{rep[:contacts]}.", :timestamp => Time.now, :image_path => "#{rep[:image_path]}")
            @user_state.delete(@message.chat.id)
        end
    end

    def get_image(args)
        if args[0] == CANCEL
            send_message("Du hast den Vorgang abgebrochen. Ich lösche deine bisherigen Eingaben")
            @user_state.delete(@message.chat.id)
            return
        end
        if @message.photo != []
            image = @bot.api.get_file(file_id: @message.photo[1].file_id)
            image_path = "#{@images}/#{@message.photo[1].file_unique_id}.jpg"
            image_temp = Down.download("https://api.telegram.org/file/bot#{@token}/#{image["result"]["file_path"]}", destination: "#{image_path}")
            @user_state[@message.chat.id][:image_path] = image_path
            rep = @user_state[@message.chat.id]
            @reports.insert(:activity => "#{rep[:date]}: #{rep[:place]}: #{rep[:activity]}", :contact => "#{rep[:contacts]}.", :timestamp => Time.now, :image_path => "#{rep[:image_path]}")
            @user_state.delete(@message.chat.id)
            send_message("Geschafft! Ich habe deine Meldung in die Datenbank aufgenommen. Vielen Dank für deine Mitarbeit.")
        else
            send_message("Du hast mir leider entweder kein Foto geschickt, oder ich kann es nicht öffnen. Bitte schicke mir Bilder direkt als Fotos und nicht als Datei. Du kannst es sofort noch einmal probieren mir zu schicken, wenn du abbrechen willst, benutze bitte /cancel.")
        end
    end

    def count
        reply("Anzahl bisheriger Meldungen: #{@reports.count}")
    end

    def all
        res = @reports.all
        reply("Übersicht über alle #{@reports.count} bisherigen Meldungen:\n\n#{format_results(res)}")
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

    def all_feedback
        send_message("Alle Feedbacks bisher lauten:\n\n#{format_feedback(@feedback.all)}")
    end

    def feedback
        @user_state[@message.chat.id] = Feedback_Inputs.new(RATING, nil, nil)
        rating = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard:[%w(1 2 3 4 5)], resize_keyboard: true)
        @bot.api.send_message(chat_id: @message.chat.id, text:"Auf einer Skala von 1 (sehr schlecht) bis 5 (sehr gut), wie gefalle ich dir?", reply_markup: rating)
    end

    def get_rating(args)
        case args[0]
        when "1"
            send_message("Oh, es tut mir Leid, dass ich deine Erwartungen nicht erfüllen konnte. Mit etwas Feedback kann ich aber betimmt besser werden!")
        when "2"
            send_message("Ohje, da gibt es wohl noch einiges für mich zu tun, um besser zu werden. Gib mir doch ein paar Tips damit meine Entwicklung auch wirklich in die richtige Richtung geht.")
        when "3"
            send_message("Na gut, da ist wohl noch etwas Luft nach oben für mich. Mit ein bisschen Feedback wird das in Zukunft bestimmt besser.")
        when "4"
            send_message("Es freut mich, dass ich dir so gut gefalle. Lass mir doch ein bisschen Feedback da um auch die letzten Probleme noch zu verbessern.")
        when "5"
            send_message("Wow, Dankeschön! Freut mich, dass ich dir so gut gefalle. Wenn du Lust hast, lass mir doch trotzdem ein kurzes Feedback da.")
        else
            send_message("Das ist leider keine gültige Bewertung, bitte schick mir eine Zahl von 1 bis 5.")
            feedback()
            return
        end
        @user_state[@message.chat.id] = Feedback_Inputs.new(ASKED_FOR_TIPS, args[0], nil)
        decision = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard:[%w(Ja Nein)], resize_keyboard: true)
        @bot.api.send_message(chat_id: @message.chat.id, text:"Möchtest du mir noch Verbesserungsvorschläge, Wünsche oder Fehlerberichte geben?", reply_markup: decision)
    end

    def get_feedback_decision(args)
        hide = Telegram::Bot::Types::ReplyKeyboardRemove.new(remove_keyboard: true, selective: nil)
        case args[0]
        when YES
            @user_state[@message.chat.id][:state] = GIVING_TIPS
            @bot.api.send_message(chat_id: @message.chat.id, text:"Was würdest du dir von mir wünschen? Was gefällt dir gut/schlecht?", reply_markup: hide)
        when NO
            @feedback.insert(:rating => @user_state[@message.chat.id].rating, :tips => "")
            @user_state.delete(@message.chat.id)
            @bot.api.send_message(chat_id: @message.chat.id, text:"In Ordnung.", reply_markup: hide)
        end
    end

    def get_tips(args)
        @user_state[@message.chat.id][:tips] = args.join(' ')
        @feedback.insert(:rating => @user_state[@message.chat.id].rating, :tips => @user_state[@message.chat.id].tips)
        @user_state.delete(@message.chat.id)
        send_message("Vielen Dank für deine Tipps! Dank dir kann ich weiterhin mein bestes geben!")
    end

    def unknown
        send_message("Sorry, ich weiß nicht was du mir sagen möchtest. Probier doch mal #{HELP}, um zu sehen was ich kann.")
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
            if @user_state[@message.chat.id] == nil
                @user_state[@message.chat.id] = Dummy.new()
            end
            case @user_state[@message.chat.id].state
            when RATING
                get_rating(args)
            when ASKED_FOR_TIPS
                get_feedback_decision(args)
            when GIVING_TIPS
                get_tips(args)
            when REPORTING_DATE
                get_report_date(args)
            when REPORTING_PLACE
                get_report_place(args)
            when REPORTING_ACTIVITY
                get_report_activity(args)
            when ASKED_FOR_CONTACTS
                get_contact_decision(args)
            when GIVING_CONTACTS
                get_contact(args)
            when ASKED_FOR_IMAGE
                get_image_decision(args)
            when GIVING_IMAGE
                get_image(args)
            else
                case args[0]
                when START # START Command, start conversation, opens greeting message
                    start()
                when HELP # HELP Command, Display all possible Commands
                    help()
                when REPORT # REPORT Command, file a new Report and put it into the Database
                    report(args)
                when FORMULAR_REPORT
                    form_report()
                when COUNT # COUNT Command, Print the Number of filed Reports
                    count()
                when ALL # ALL Command, Print all filed Reports
                    all()
                when LAST # LAST Command, Print all filed Reports from the last 7 (or 'd', if specified) days
                    last(args)
                when FEEDBACK
                    feedback()
                when ALL_FEEDBACK
                    all_feedback()
                else
                    unknown()
                end
            end
        end
    end     
end
