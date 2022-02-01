require './lib/registerbot/basic_processor'
require 'telegram/bot'
require 'sequel'
require 'down'
require 'fileutils'

# The maximum size of a photo to download to the image folder
MAX_PHOTO_SIZE = 100000

# A Processor for `message`s that revolve around the user making reports or asking to view older reports.
#   Inherits from `Basic_processor` class (see #Basic_processor)
class Reports_processor < Basic_processor

    # The Struct behind the `user_state`. 
    #   Contains the state, the incident date, place and activity of the incident, a contact to the reporting person if given and the image id (which doubles as the file name)
    #   After the entrys are stored in the Database, the `user_state` is set back to nil.
    Report_Inputs = Struct.new(:state, :date, :place, :activity, :contacts, :image_path)

    # Creates a new `Reports_processor` instance.
    #
    # @note the initialize method calls the initialize of the superclass `Basic_processor` (see #Basic_processor)
    # @param bot [Telegram::Bot::Client] the actual bot communicating with the telegram bot-API
    # @param reports_db [Sequel::Dataset] the Database table to store all received reports in,
    #   requires the fields 'id', 'date', 'place', 'activity', 'contact', 'image_path' and 'timestamp'
    # @param image_path [String] the path to the folder containing the images downloaded from the reports
    # @param down_url [String] the API URL to download the images from
    # @note reports_db requires specific fields! Those are: 
    #   'primary_key :id', 'String :date', 'String :place', 'String :activity', 'String :contact', 'String :image_path' 'Float :timestamp'
    def initialize(bot, reports_db, image_path, down_url, logger)
        super(bot, logger)
        @reports = reports_db
        @images = image_path
        @download_url = down_url
    end

    # Formats the Array of Hashes retrieved from a Dataset/Databse query into a more readable Format.
    #   If a reports contains a photo, instead of adding it to the message, a little camera emoji is sent along the report. use the INSPECT command to view it.
    #
    # @param res [Array] an Array of Hashes as received by a Database query. 
    #   Hashes must contain the fields of the feedback database 'id', 'date', 'place', 'activity' and 'timestamp'
    # @note res is required to contain specific fields! Those are: 
    #   'primary_key :id', 'String :date', 'String :place', 'String :activity', 'String :image_path' 
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

    # Give a closer look at one specific record, showing the full text and image.
    #
    # @param args [Array] the array of Strings containing the words of the user message one by one. For this method to work, there needs to be at least 1 number after the command
    # @param message [Telegram::Bot::Types::Message] the original messaged received from the user containing all reports 
    def inspect(args, message)
        # Check if valid number was given
        begin
            d = Integer(args[1])
        rescue
            reply("Du hast keine valide Zahl angegeben, bitte versuche es noch einmal.", message)
            return
        end
        # check if a report with that id exists
        if d <= 0
            reply("Bitte gib eine Zahl größer als 0 an.", message)
            return
        end
        report = @reports.select(:id, :date, :place, :activity, :image_path, :timestamp).order(:id).where(id: d).all
        if report == []
            send_message("Es existiert keine Meldung mit der Nummer #{d}.", message)
            return
        end
        # print the details
        time = Time.at(report[0][:timestamp])
        date = "Gemeldet am: #{time.day}.#{time.month}.#{time.year} um #{time.hour}:#{time.min < 10 ? "0#{time.min}" : time.min}"
        text = "#{report[0][:date]}: #{report[0][:place]}: #{report[0][:activity]}"
        if "#{report[0][:image_path]}" == ""
            send_message("Die Meldung Nummer #{d} lautet:\n\n#{text}\n#{date}", message)
        else
            @bot.api.send_photo(chat_id: message.chat.id, caption: "Die Meldung Nummer #{d} lautet:\n\n#{text}\n#{date}", photo: report[0][:image_path])
        end
    end

    # Return the Reports of the last 'days' Days from the Dataset
    #
    # @param days [Integer] the number of past days of which you want to see the reports
    def get_last_days(days)
        now = Time.now
        @reports.select(:id, :date, :place, :activity).order(:id).where{timestamp > (now - (2592000 * days)).to_f}.all
    end

    # @deprecated The original way to file reports. This requires a very special format for the reports given by the user,
    #   which makes is unsuited for common user interaction.
    #
    # @param args [Array] the array of Strings containing the words of the user message one by one
    # @param message [Telegram::Bot::Types::Message] the original messaged received from the user containing all reports 
    def report(args, message)
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

    # Start the Conversation with the user to get the report details, explain how to abort the conversation and ask the first question
    #
    # @param message [Telegram::Bot::Types::Message] the original message received from the user
    # @note This method may modify our application state
    def form_report(message)
        send_message("Okay, du kannst mir jetzt Schritt für Schritt die Daten einer Meldung durchgeben. Wenn du dich zwischendurch umentscheidest benutze #{CANCEL} um den Vorgang abzubrechen, dann lösche ich alle Teile der Meldung die du mir bisher gesagt hast.\nLass uns mit dem Datum anfangen; wann hast du etwas beobachtet?", message)
        @user_state[message.chat.id] = Report_Inputs.new(REPORTING_DATE, nil, nil, nil, nil, nil)    
    end

    # Get the incident date from the user and store it in the `user_state`. 
    #
    # @param args [Array] array of strings containing the user message word by word
    # @param message [Telegram::Bot::Types::Message] the original message received from the user giving the incident date
    # @note as this message sets the `user_state` to 'REPORTING_PLACE' the next message received in the chat MUST contain the incident location
    #   and is directed to the `get_report_place()` method (see #get_report_place)
    # @note This method may modify our application state
    def get_report_date(args, message)
        if args[0] == CANCEL
            send_message("Du hast den Vorgang abgebrochen. Ich lösche deine bisherigen Eingaben", message)
            @user_state.delete(message.chat.id)
            return
        end
        @user_state[message.chat.id] = Report_Inputs.new(REPORTING_PLACE, args.join(' '), nil, nil, nil, nil)
        send_message("Super! Als nächstes sag mir bitte, wo du etwas beobachtet hast.", message)
    end

    # Get the incident location from the user and store it in the `user_state`. 
    #
    # @param args [Array] array of strings containing the user message word by word
    # @param message [Telegram::Bot::Types::Message] the original message received from the user giving the incident location
    # @note as this message sets the `user_state` to 'REPORTING_ACTIVITY' the next message received in the chat MUST contain the incident description
    #   and is directed to the `get_report_activity()` method (see #get_report_activity)
    # @note This method may modify our application state
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

    # Get the incident description from the user and store it in the `user_state`. 
    #
    # @param args [Array] array of strings containing the user message word by word
    # @param message [Telegram::Bot::Types::Message] the original message received from the user giving the incident description
    # @note as this message sets the `user_state` to 'ASKED_FOR_CONTACTS' the next message received in the chat MUST contain the answer to giving contacts
    #   and is directed to the `get_contact_decision()` method (see #get_contact_decision)
    # @note This method may modify our application state
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

    # Get the answer sent by the user, whether they want to provide contact information or not and if yes, query them for the contact information,
    #   otherwise query the user for providing an image. If neither yes or no is answered, query the user again.
    #   Since no `Telegram::Bot::Types::ReplyKeyboardRemove` is sent with the new query, the old yes/no markup should still be in place.
    #
    # @param answer [String] usually the first word of the message text, containg the answer (yes or no). 
    #   If not a yes or no the bot will once again query the user for a valid answer
    # @param message [Telegram::Bot::Types::Message] the original message received from the user giving the answer
    # @note as this message sets the `user_state` to 'GIVING_CONTACTS' when yes is answered, the next message received in the chat MUST contain the user contact
    #   and is directed to the `get_contact()` method (see #get_contact)
    # @note as this message sets the `user_state` to 'ASKED FOR IMAGE' when no is answered, the next message received in the chat MUST contain the answer to
    #   providing an image and is directed to the `get_iamge_decision()` method (see #get_image_decision)
    # @note This method may modify our application state 
    def get_contact_decision(answer, message)
        if answer == CANCEL
            send_message("Du hast den Vorgang abgebrochen. Ich lösche deine bisherigen Eingaben", message)
            @user_state.delete(message.chat.id)
            return
        end
        hide = Telegram::Bot::Types::ReplyKeyboardRemove.new(remove_keyboard: true, selective: nil)
        case answer
        when YES
            @user_state[message.chat.id][:state] = GIVING_CONTACTS
            send_message_with_markup("Wie bist du zu erreichen? (E-Mail / Telefon / Telegram / oä)", message, hide)
        when NO
            @user_state[message.chat.id][:contacts] = "Keine Kontaktmöglichkeit hinterlassen"
            @user_state[message.chat.id][:state] = ASKED_FOR_IMAGE
            send_message_with_markup("In Ordnung.", message, hide)
            decision = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard:[%w(Ja Nein)], resize_keyboard: true)
            send_message_with_markup("Fast geschafft. Noch als letztes, möchtest du mir ein Foto von der Entdeckung schicken?", message, decision)
        else
            send_message("Das habe ich nicht verstanden. Möchtest du mir eine Kontaktmöglichkeit?", message)
        end
    end

    # Get the user contact information from the user and store it in the `user_state`. 
    #
    # @param args [Array] array of strings containing the user message word by word
    # @param message [Telegram::Bot::Types::Message] the original message received from the user giving the user contact information
    # @note as this message sets the `user_state` to 'ASKED_FOR_IMAGE' the next message received in the chat MUST contain the answer to providing an image
    #   and is directed to the `get_image_decision()` method (see #get_image_decision)
    # @note This method may modify our application state
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

    # Get the answer sent by the user, whether they want to provide an image or not and if yes, query them for the image,
    #   otherwise store the report in the Database. If neither yes or no is answered, query the user again.
    #   Since no `Telegram::Bot::Types::ReplyKeyboardRemove` is sent with the new query, the old yes/no markup should still be in place.
    #
    # @param answer [String] usually the first word of the message text, containg the answer (yes or no). 
    #   If not a yes or no the bot will once again query the user for a valid answer
    # @param message [Telegram::Bot::Types::Message] the original message received from the user giving the answer
    # @note as this message sets the `user_state` to 'GIVING_IMAGE' when yes is answered, the next message received in the chat MUST contain the image
    #   and is directed to the `get_image()` method (see #get_image)
    # @note as this message deletes the `user_state` when no is answered the next message received in the chat can contain any command again
    # @note This method may modify our application state 
    def get_image_decision(answer, message)
        if answer == CANCEL
            send_message("Du hast den Vorgang abgebrochen. Ich lösche deine bisherigen Eingaben", message)
            @user_state.delete(message.chat.id)
            return
        end
        hide = Telegram::Bot::Types::ReplyKeyboardRemove.new(remove_keyboard: true, selective: nil)
        case answer
        when YES
            @user_state[message.chat.id][:state] = GIVING_IMAGE
            send_message_with_markup("Super, dann schick mir doch bitte das Foto.", message, hide)
        when NO
            send_message_with_markup("In Ordnung, ich habe deine Meldung der Datenbank hinzugefügt. Danke für deine Mitarbeit!", message, hide)
            @user_state[message.chat.id][:image_path] = ""
            rep = @user_state[message.chat.id]
            @reports.insert(:date => rep[:date], :place => rep[:place], :activity => rep[:activity], :contact => rep[:contacts], :timestamp => Time.now.to_f, :image_path => "#{rep[:image_path]}")
            @user_state.delete(message.chat.id)
        else
            send_message("Das habe ich nicht verstanden. Möchtest du mir ein Foto von der Entdeckung schicken?", message)
        end
    end

    # From a set of attached `photo_sizes` find the one which is the largest one that's still below the maximum file size
    #
    # @param message [Telegram::Bot::Types::Message] the original message received from the user providing the image `photo_size`s and id's
    # @return [Integer] the id of the best sized photo
    def find_correct_image(message)
        i = 0
        message.photo.each do |photo|
            if photo.file_size > MAX_PHOTO_SIZE
                return i - 1
            end
            i += 1
        end
    end

    # Get the image provided by the user and store it in the Database. 
    #
    # @param args [Array] array of strings containing the user message word by word
    # @param message [Telegram::Bot::Types::Message] the original message received from the user providing the image
    # @note as this message deletes the `user_state` the next message received in the chat can contain any command again
    # @note this method calls `find_correct_image()` method (see #find_correct_image) to identify the image with the best size for downloading
    # @note This method may modify our application state 
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

    # Return the number of reports found in the Database
    #
    # @param message [Telegram::Bot::Types::Message] the original message received from the user asking for the amount of reports
    def count(message)
        send_message("Anzahl bisheriger Meldungen: #{@reports.count}", message)
    end

    # Return all reports found in the Database, reports are cut off after 120 Characters, use INSPECT command to see the entire text of a report
    #
    # @param message [Telegram::Bot::Types::Message] the original message received from the user asking for the reports
    # @note this method calls `format_results()` method (see #format_results) to make the query result readable for the user
    def all(message)
        res = @reports.all
        reply("Übersicht über alle #{@reports.count} bisherigen Meldungen\nEine kleine Kamera neben einer Meldung zeigt, dass zu dieser Meldung auch ein Foto existiert. Benutze #{INSPECT} <Nummer> um dir die Meldung und das Foto anzusehen.\n\n#{format_results(res)}", message)
    end

    # Return all reports found in the Database from the last days. If no argument is given, defaults to last 7 days
    #
    # @param args [Array] array of `String`s containing the words of the user message.
    #   If an argument with a valid `Integer` or no argeument is given, return the reports
    # @param message [Telegram::Bot::Types::Message] the original message received from the user asking for the reports
    # @note this method calls `format_results()` method (see #format_results) to make the query result readable for the user
    # @note this method calls `get_last_days()` method (see #get_last_days) to query the database
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