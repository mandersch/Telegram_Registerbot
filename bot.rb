require 'telegram/bot'
require 'sequel'
require 'FileUtils'
require 'down'
require 'logger'

logger = Logger.new(STDOUT)
logger.level = Logger::DEBUG

TOKEN_PATH = "token.priv"
IMAGE_PATH = "images"
DB_FOLDER = "data"
DB_FILE = "reports.db"

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

# Return the Reports of the last 'd' Days from the Dataset
def get_last_days(days, db)
    now = Time.now
    db.select(:id, :activity).order(:id).where{timestamp > (now - (2592000 * days)).to_f}.all
end

# Method to turn the Array of Hashes from the Dataset into a String with Delimiters between Reports
def format_results(res)
    reports = []
    res.each { |report|
        reports << "Meldung Nummer #{report[:id]}: #{report[:activity].inspect}"
    }
    reports.join("\n--------\n")
end

# Open the Database file
begin
    Dir.mkdir(DB_FOLDER) unless File.exists?(DB_FOLDER)
    DB = Sequel.sqlite("#{DB_FOLDER}/#{DB_FILE}")
rescue
    logger.fatal("Fatal Error Occured during Database initialisation.")
    return
end

# Check if the Image folder can be accessed
begin
    Dir.mkdir(IMAGE_PATH) unless File.exists?(IMAGE_PATH)
rescue
    logger.fatal("Imagefolder could neither be opened, nor created")
    return
end


# Create Table
# TODO: Add image field
unless DB.table_exists?(:items)
    DB.create_table :items do
        primary_key :id
        String :activity
        Float :timestamp
    end
end

# Open Table
items = DB[:items]

# The Telegram API Bot token. Should be stored in a token.priv file.
begin
    token_file = File.new(TOKEN_PATH, "r")
    token =""
    if token_file
        token_file.each_line do |line|
            token += line
        end
    end
    token_file.close
rescue
    logger.fatal("Error occured during Token reading.")
    return
end

# Create new Bot and make it listen to commands
# TODO: make send_message and reply their own method
# TODO: Errorhandling on Server Communication
Telegram::Bot::Client::run(token) do |bot|
    bot.listen do |message|
        text = ""
        if message.text != nil
            text = message.text
        elsif message.caption != nil
            text = message.caption
        end
        args = text.split(' ')
        case args[0]
        when START # START Command, start conversation, opens greeting message
            bot.api.send_message(chat_id: message.chat.id, text: "Hallo #{message.from.first_name}! Ich bin ein Bot für Meldungen rechter Aktivitäten in Berlin Charlottenburg-Wilmersdorf. Wenn du mehr über das Register erfahren möchtest, dann schau doch mal auf die Website: https://berliner-register.de/charlottenburg-wilmersdorf.\n\nBei mir kannst du ganz einfach per Telegram-Nachricht Meldungen durchgeben, ohne erst viel auf Websiten oder E-Mails rumsuchen zu müssen. Probier doch glech einmal den /hilfe Befehl, um zu sehen, was ich alles kann.\n\nHinweis: Ich bin kein offizielles Produkt des Berliner Registers, sondern ein privates Projekt zur Unterstützung desselben. Ich befinde mich aktuell noch sehr am Anfang meiner Entwicklung, also entschuldige bitte den kleinen Funktionsumfang und einzelne Bugs.")
        when HELP # HELP Command, Display all possible Commands
            bot.api.send_message(chat_id: message.chat.id, text: "Folgende Befehle kannst du aktuell benutzen:\n\n#{START}: Zeigt die Begrüßungsnachricht an.\n\n#{HELP}: Zeigt alle Verfügbaren Befehle an.\n\n#{COUNT}: Zeigt die Gesamtzahl der beim Bot eingegangenen Meldungen an.\n\n#{ALL}: Gibt ALLE eingegangenen Meldungen aus (Leider noch unformatiert und schlecht lesbar)\n\n#{REPORT} <Meldung>: Gib uns eine neue Meldung an, am besten in folgendem Format: <Datum des Geschehens/der Entdeckung> <Ort> <Geschehnis/Entdeckung> <Kontaktmöglichkeit für Rückfragen(optional)>. Du kannst auch mehrere Meldungen auf einmal abgeben, indem du diese mit dem Prozentzeichen '%' trennst.\n\n#{LAST} <(optional) Tage>: Gibt die Meldungen der letzten 7 Tage aus. Du kannst selber eine Anzahl an Tagen angeben, von denen du die Meldungen sehen möchtest.")
        when REPORT # REPORT Command, file a new Report and put it into the Database
            if args.count < 2
                bot.api.send_message(chat_id: message.chat.id, text:"Du hast mir leider keine Meldung mitgeteilt. Bitte schreibe nach dem '/meldung' ein paar Worte.", reply_to_message: message)
            else
                if message.photo != nil
                    puts "#{message.photo[1].file_id}"
                    image = bot.api.get_file(file_id: message.photo[1].file_id)
                    image_temp = Down.download("https://api.telegram.org/file/bot#{token}/#{image["result"]["file_path"]}", destination: "./images/#{message.photo[1].file_unique_id}.jpg")
                end
                act = args[1..-1].join(' ')
                act = act.split("%")
                act.each { |report|
                    items.insert(:activity => report.strip(), :timestamp => Time.now.to_f) 
                }
                if act.count > 1
                    bot.api.send_message(chat_id: message.chat.id, text:"Ich habe deine Meldungen zur Datenbank hinzugefügt. Danke für deine Mithilfe", reply_to_message: message)
                else
                    bot.api.send_message(chat_id: message.chat.id, text:"Ich habe deine Meldung #{act[0].inspect} zur Datenbank hinzugefügt. Danke für deine Mitarbeit.", reply_to_message: message)
                end
            end
        when COUNT # COUNT Command, Print the Number of filed Reports
            bot.api.send_message(chat_id: message.chat.id, reply_to_message: message, text:"Anzahl bisheriger Meldungen: #{items.count}")
        when ALL # ALL Command, Print all filed Reports
            res = items.all
            bot.api.send_message(chat_id: message.chat.id, reply_to_message: message, text:"Übersicht über alle bisherigen Meldungen:\n\n#{format_results(res)}")
        when LAST # LAST Command, Print all filed Reports from the last 7 (or 'd', if specified) days
            if args.count < 2
                bot.api.send_message(chat_id: message.chat.id, text:"Die Meldungen der letzten 7 Tage lauten:\n\n#{format_results(get_last_days(7,items))}")
            else
                begin
                    d = Integer(args[1])
                rescue
                    bot.api.send_message(chat_id: message.chat.id, reply_to_message: message, text:"Du hast keine valide Zahl angegeben, bitte versuche es noch einmal.")
                else
                    if d <= 0
                        bot.api.send_message(chat_id: message.chat.id, reply_to_message: message, text:"Bitte gib eine Zahl größer als 0 an.")
                    else
                        bot.api.send_message(chat_id: message.chat.id, text:"Die Meldungen der letzten #{d} Tage lauten:\n\n#{format_results(get_last_days(d,items))}")
                    end
                end
            end
        when FEEDBACK
            rating = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard:[%w(1 2 3 4 5)], one_time_keyboard: true, resize_keyboard: true)
            bot.api.send_message(chat_id: message.chat.id, text:"Auf einer Skala von 1 (sehr schlecht) bis 5 (sehr gut), wie gefalle ich dir?", reply_markup: rating)
        end
    end
end