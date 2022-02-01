require 'sequel'
require 'fileutils'
require 'logger'
require './lib/registerbot'

logger = Logger.new(STDOUT)
logger.level = Logger::WARN

TOKEN_PATH = "token.priv"
IMAGE_PATH = "images"
LOG_PATH = "log"
LOG_FILE = "log.txt"
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

# Check if the Log folder can be accessed
begin
    Dir.mkdir(LOG_PATH) unless File.exists?(LOG_PATH)
    log_path = "#{LOG_PATH}/#{LOG_FILE}"
    unless File.exists?(log_path)
        log_file = File.new(log_path, "w+") 
        log_file.close()
    end

rescue
    logger.error("Logfolder could neither be opened, nor created")
    return
end

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


register_bot = Registerbot.new(token, DB, IMAGE_PATH,log_path)
register_bot.run




