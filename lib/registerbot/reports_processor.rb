require './lib/registerbot/basic_processor'
require 'telegram/bot'
require 'sequel'
require 'fileutils'

class Reports_processor < Basic_processor
    Report_Inputs = Struct.new(:state, :date, :place, :activity, :contacts, :image_path)
    def initialize(bot, reports_db, image_path, down_url)
        super(bot)
        @reports = reports_db
        @images = image_path
        @download_url = down_url
    end

    # Method to turn the Array of Hashes from the Dataset into a String with Delimiters between Reports
    def format_results(res)
        reports = []
        res.each { |report|
            reports << "Meldung Nummer #{report[:id]}: #{report[:activity].inspect}"
        }
        reports.join("\n--------\n")
    end

    # Return the Reports of the last 'd' Days from the Dataset
    def get_last_days(days)
        now = Time.now
        @reports.select(:id, :activity).order(:id).where{timestamp > (now - (2592000 * days)).to_f}.all
    end

    def report(args, message) #TODO: Needs complete overhaul, is working, but is pretty shitty rn
        if args.count < 2
            reply("Du hast mir leider keine Meldung mitgeteilt. Bitte schreibe nach dem '/meldung' ein paar Worte.", message)
        else
            if message.photo != []
                image = @bot.api.get_file(file_id: message.photo[1].file_id)
                image_temp = Down.download("#{@download_url}/#{image["result"]["file_path"]}", destination: "#{@images}/#{message.photo[1].file_unique_id}.jpg")
            end
            act = args[1..-1].join(' ')
            act = act.split("%")
            act.each { |report|
                @reports.insert(:activity => report.strip(), :timestamp => Time.now.to_f) 
            }
            if act.count > 1
               reply("Ich habe deine Meldungen zur Datenbank hinzugefügt. Danke für deine Mithilfe", message)
            else
                reply("Ich habe deine Meldung #{act[0].inspect} zur Datenbank hinzugefügt. Danke für deine Mitarbeit.", message)
            end
        end
    end

    def form_report(message)
        send_message("Okay, du kannst mir jetzt Schritt für Schritt die Daten einer Meldung durchgeben. Wenn du dich zwischendurch umentscheidest benutze #{CANCEL} um den Vorgang abzubrechen, dann lösche ich alle Teile der Meldung die du mir bisher gesagt hast.\nLass uns mit dem Datum anfangen; wann hast du etwas beobachtet?", message)
        @user_state[message.chat.id] = Report_Inputs.new(REPORTING_DATE, nil, nil, nil, nil, nil)
    end

    def get_report_date(args, message)
        if args[0] == CANCEL
            send_message("Du hast den Vorgang abgebrochen. Ich lösche deine bisherigen Eingaben", message)
            @user_state.delete(message.chat.id)
            return
        end
        @user_state[message.chat.id] = Report_Inputs.new(REPORTING_PLACE, args.join(' '), nil, nil, nil, nil)
        send_message("Super! Als nächstes sag mir bitte, wo du etwas beobachtet hast.", message)
    end

    def get_report_place(args, message)
        if args[0] == CANCEL
            send_message("Du hast den Vorgang abgebrochen. Ich lösche deine bisherigen Eingaben", message)
            @user_state.delete(message.chat.id)
            return
        end
        @user_state[message.chat.id][:state] = REPORTING_ACTIVITY
        @user_state[message.chat.id][:place] = args.join(' ')
        send_message("Gut, als nächstes das allerwichtigte: Was hast du beobachtet?", message)
    end

    def get_report_activity(args, message)
        if args[0] == CANCEL
            send_message("Du hast den Vorgang abgebrochen. Ich lösche deine bisherigen Eingaben", message)
            @user_state.delete(message.chat.id)
            return
        end
        @user_state[message.chat.id][:state] = ASKED_FOR_CONTACTS
        @user_state[message.chat.id][:activity] = args.join(' ')
        decision = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard:[%w(Ja Nein)], resize_keyboard: true)
        send_message_with_markup("Okay, das hätten wir. Möchtest du mir noch eine Kontaktmöglichkeit hinterlassen falls sich Rückfragen zu deiner Meldung ergeben?", message, decision)
    end

    def get_contact_decision(args, message)
        if args[0] == CANCEL
            send_message("Du hast den Vorgang abgebrochen. Ich lösche deine bisherigen Eingaben", message)
            @user_state.delete(message.chat.id)
            return
        end
        hide = Telegram::Bot::Types::ReplyKeyboardRemove.new(remove_keyboard: true, selective: nil)
        case args[0]
        when YES
            @user_state[message.chat.id][:state] = GIVING_CONTACTS
            send_message_with_markup("Wie bist du zu erreichen? (E-Mail / Telefon / Telegram / oä)", message, hide)
        when NO
            @user_state[message.chat.id][:contacts] = "Keine Kontaktmöglichkeit hinterlassen"
            @user_state[message.chat.id][:state] = ASKED_FOR_IMAGE
            send_message_with_markup("In Ordnung.", message, hide)
            decision = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard:[%w(Ja Nein)], resize_keyboard: true)
            send_message_with_markup("Fast geschafft. Noch als letztes, möchtest du mir ein Foto von der Entdeckung schicken?", message, decision)
        end
    end

    def get_contact(args, message)
        if args[0] == CANCEL
            send_message("Du hast den Vorgang abgebrochen. Ich lösche deine bisherigen Eingaben", message)
            @user_state.delete(message.chat.id)
            return
        end
        @user_state[message.chat.id][:state] = ASKED_FOR_IMAGE
        @user_state[message.chat.id][:contacts] = args.join(' ')
        decision = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard:[%w(Ja Nein)], resize_keyboard: true)
        send_message_with_markup("Super, fast geschafft. Noch als letztes, möchtest du mir ein Foto von der Entdeckung schicken?", message, decision)
    end

    def get_image_decision(args, message)
        if args[0] == CANCEL
            send_message("Du hast den Vorgang abgebrochen. Ich lösche deine bisherigen Eingaben", message)
            @user_state.delete(message.chat.id)
            return
        end
        hide = Telegram::Bot::Types::ReplyKeyboardRemove.new(remove_keyboard: true, selective: nil)
        case args[0]
        when YES
            @user_state[message.chat.id][:state] = GIVING_IMAGE
            send_message_with_markup("Super, dann schick mir doch bitte das Foto.", message, hide)
        when NO
            send_message_with_markup("In Ordnung, ich habe deine Meldung der Datenbank hinzugefügt. Danke für deine Mitarbeit!", message, hide)
            @user_state[message.chat.id][:image_path] = "Kein Bild angegeben."
            rep = @user_state[message.chat.id]
            @reports.insert(:activity => "#{rep[:date]}: #{rep[:place]}: #{rep[:activity]}", :contact => "#{rep[:contacts]}.", :timestamp => Time.now.to_f, :image_path => "#{rep[:image_path]}")
            @user_state.delete(message.chat.id)
        end
    end

    def get_image(args, message)
        if args[0] == CANCEL
            send_message("Du hast den Vorgang abgebrochen. Ich lösche deine bisherigen Eingaben", message)
            @user_state.delete(message.chat.id)
            return
        end
        if message.photo != []
            image = @bot.api.get_file(file_id: message.photo[1].file_id)
            image_path = "#{@images}/#{message.photo[1].file_unique_id}.jpg"
            image_temp = Down.download("#{@download_url}/#{image["result"]["file_path"]}", destination: "#{image_path}")
            @user_state[message.chat.id][:image_path] = image_path
            rep = @user_state[message.chat.id]
            @reports.insert(:activity => "#{rep[:date]}: #{rep[:place]}: #{rep[:activity]}", :contact => "#{rep[:contacts]}.", :timestamp => Time.now.to_f, :image_path => "#{rep[:image_path]}")
            @user_state.delete(message.chat.id)
            send_message("Geschafft! Ich habe deine Meldung in die Datenbank aufgenommen. Vielen Dank für deine Mitarbeit.", message)
        else
            send_message("Du hast mir leider entweder kein Foto geschickt, oder ich kann es nicht öffnen. Bitte schicke mir Bilder direkt als Fotos und nicht als Datei. Du kannst es sofort noch einmal probieren mir zu schicken, wenn du abbrechen willst, benutze bitte /cancel.", message)
        end
    end

    def count(message)
        send_message("Anzahl bisheriger Meldungen: #{@reports.count}", message)
    end

    def all(message)
        res = @reports.all
        reply("Übersicht über alle #{@reports.count} bisherigen Meldungen:\n\n#{format_results(res)}", message)
    end

    def last(args, message)
        if args.count < 2
            send_message("Die Meldungen der letzten 7 Tage lauten:\n\n#{format_results(get_last_days(7))}", message)
        else
            begin
                d = Integer(args[1])
            rescue
                reply("Du hast keine valide Zahl angegeben, bitte versuche es noch einmal.", message)
            else
                if d <= 0
                    reply("Bitte gib eine Zahl größer als 0 an.", message)
                else
                    send_message("Die Meldungen der letzten #{d} Tage lauten:\n\n#{format_results(get_last_days(d))}", message)
                end
            end
        end
    end
end