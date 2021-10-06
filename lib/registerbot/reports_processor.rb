require './lib/registerbot/basic_processor'
require 'telegram/bot'
require 'sequel'
require 'fileutils'

MAX_PHOTO_SIZE = 100000

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
            img = ""
            if report[:image_path] != ""
                img = "\xF0\x9F\x93\xB7"
            end
            if report[:activity].length > 120
                text = "#{report[:date]}: #{report[:place]}: #{report[:activity][0..119]}..."
            else
                text = "#{report[:date]}: #{report[:place]}: #{report[:activity]}"
            end
            reports << "Meldung Nummer #{report[:id]}: #{text.inspect} #{img}"
        }
        reports.join("\n--------\n")
    end

    def inspect(args, message)
        begin
            d = Integer(args[1])
        rescue
            reply("Du hast keine valide Zahl angegeben, bitte versuche es noch einmal.", message)
            return
        end
        if d <= 0
            reply("Bitte gib eine Zahl größer als 0 an.", message)
            return
        end
        report = @reports.select(:id, :date, :place, :activity, :image_path, :timestamp).order(:id).where(id: d).all
        if report == []
            send_message("Es existiert keine Meldung mit der Nummer #{d}.", message)
            return
        end
        time = Time.at(report[0][:timestamp])
        date = "Gemeldet am: #{time.day}.#{time.month}.#{time.year} um #{time.hour}:#{time.min < 10 ? "0#{time.min}" : time.min}"
        text = "#{report[0][:date]}: #{report[0][:place]}: #{report[0][:activity]}"
        if "#{report[0][:image_path]}" == ""
            send_message("Die Meldung Nummer #{d} lautet:\n\n#{text}\n#{date}", message)
        else
            @bot.api.send_photo(chat_id: message.chat.id, caption: "Die Meldung Nummer #{d} lautet:\n\n#{text}\n#{date}", photo: report[0][:image_path])
        end
    end

    # Return the Reports of the last 'd' Days from the Dataset
    def get_last_days(days)
        now = Time.now
        @reports.select(:id, :date, :place, :activity).order(:id).where{timestamp > (now - (2592000 * days)).to_f}.all
    end

    def report(args, message) #TODO: Needs complete overhaul, is working, but is pretty shitty rn
        if args.count < 2
            reply("Du hast mir leider keine Meldung mitgeteilt. Bitte schreibe nach dem '/meldung' ein paar Worte.", message)
        else
            act = args[1..-1].join(' ')
            act = act.split("%")
            rep = []
            act.each { |report|
                reps = report.strip().split(";")
                if reps.count == 3
                    reps[3] = "Keine Kontaktmöglichkeit angegeben"
                elsif reps.count != 4
                    send_message("Da hat Leider etwas mit deiner Formatierung nicht geklappt. Überprüfe noch einmal ob du Datum, Ort, Aktivität und optional auch Kontaktmöglichkeit wirklich mit einem Semikolon ';' getrennt hast bzw., dass du keine anderen Semikolons verwendet hast. Wenn du Probleme haben solltest, benutze lieber #{FORMULAR_REPORT}.", message)
                    return
                end
                rep.append(reps)
            }
            rep.each { |reps| 
                @reports.insert(:date => reps[0], place => reps[1], :activity =>reps[2], :contact => reps[3], :timestamp => Time.now.to_f, :image_path => "")
            }
            reply("Ich habe deine Meldungen zur Datenbank hinzugefügt. Danke für deine Mithilfe", message)

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
            @user_state[message.chat.id][:image_path] = ""
            rep = @user_state[message.chat.id]
            @reports.insert(:date => rep[:date], :place => rep[:place], :activity => rep[:activity], :contact => rep[:contacts], :timestamp => Time.now.to_f, :image_path => "#{rep[:image_path]}")
            @user_state.delete(message.chat.id)
        end
    end

    def find_correct_image(message)
        i = 0
        message.photo.each do |photo|
            if photo.file_size > MAX_PHOTO_SIZE
                return i - 1
            end
            i += 1
        end
    end

    def get_image(args, message)
        if args[0] == CANCEL
            send_message("Du hast den Vorgang abgebrochen. Ich lösche deine bisherigen Eingaben", message)
            @user_state.delete(message.chat.id)
            return
        end
        if message.photo != []
            img_nr = find_correct_image(message)
            if img_nr < 0
                send_message("Das Bild ist zu groß für mich zum Herunterladen, bitte schicke mir ein anderes.", message)
                return
            end
            image = @bot.api.get_file(file_id: message.photo[img_nr].file_id)
            image_path = "#{@images}/#{message.photo[img_nr].file_id}.jpg"
            image_temp = Down.download("#{@download_url}/#{image["result"]["file_path"]}", destination: "#{image_path}")
            @user_state[message.chat.id][:image_path] = message.photo[img_nr].file_id
            rep = @user_state[message.chat.id]
            @reports.insert(:date => rep[:date], :place => rep[:place], :activity => rep[:activity], :contact => rep[:contacts], :timestamp => Time.now.to_f, :image_path => "#{rep[:image_path]}")
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
        reply("Übersicht über alle #{@reports.count} bisherigen Meldungen\nEine kleine Kamera neben einer Meldung zeigt, dass zu dieser Meldung auch ein Foto existiert. Benutze #{INSPECT} <Nummer> um dir die Meldung und das Foto anzusehen.\n\n#{format_results(res)}", message)
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