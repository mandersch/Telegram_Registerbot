require 'sequel'
require 'fileutils'
require 'logger'
require './lib/registerbot'

logger = Logger.new(STDOUT)
logger.level = Logger::WARN

TOKEN_PATH = "token.priv"
IMAGE_PATH = "images"
DB_FOLDER = "data"
DB_FILE = "reports.db"

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
unless DB.table_exists?(:reports)
    DB.create_table :reports do
        primary_key :id
        String :activity
        Float :timestamp
        String :image_path
    end
end

unless DB.table_exists?(:feedback)
    DB.create_table :feedback do
        primary_key :id
        String :rating
        String :tips
    end
end

# Open Table
reports = DB[:reports]
feedback = DB[:feedback]

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


register_bot = Registerbot.new(token, reports, feedback, IMAGE_PATH)
register_bot.bot_loop




