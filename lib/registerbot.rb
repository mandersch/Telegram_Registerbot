require 'telegram/bot'
require 'sequel'
require 'down'
require 'fileutils'
require 'logger'
require './lib/registerbot/feedback_processor'
require './lib/registerbot/reports_processor'
require './lib/registerbot/help_processor'
require './lib/registerbot/commands'

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
    logger = Logger.new(STDOUT)
    logger.level = Logger::DEBUG   
    def initialize(bot_token, report_db, feedback_db, image_path)
        Telegram::Bot::Client::run(bot_token) do |reg_bot|
            @bot = reg_bot
        end
        download_url = "https://api.telegram.org/file/bot#{bot_token}"
        @reports_processor = Reports_processor.new(@bot, report_db, image_path, download_url)
        @feedback_processor = Feedback_processor.new(@bot, feedback_db)
        @help_processor = Help_processor.new(@bot)
    end

    def bot_loop
        @bot.listen do |message|
            text = ""
            if message.text != nil
                text = message.text
            elsif message.caption != nil
                text = message.caption
            end
            args = text.split(' ')
            id = message.chat.id
            user_state = nil
            if @feedback_processor.user_state[id] != nil
                user_state = @feedback_processor.user_state[id].state
            elsif @reports_processor.user_state[id] != nil
                    user_state = @reports_processor.user_state[id].state
            end
            case user_state
            when RATING
                @feedback_processor.get_rating(args[0], message)
            when ASKED_FOR_TIPS
                @feedback_processor.get_feedback_decision(args[0], message)
            when GIVING_TIPS
                @feedback_processor.get_tips(message)
            when REPORTING_DATE
                @reports_processor.get_report_date(args, message)
            when REPORTING_PLACE
                @reports_processor.get_report_place(args, message)
            when REPORTING_ACTIVITY
                @reports_processor.get_report_activity(args, message)
            when ASKED_FOR_CONTACTS
                @reports_processor.get_contact_decision(args, message)
            when GIVING_CONTACTS
                @reports_processor.get_contact(args, message)
            when ASKED_FOR_IMAGE
                @reports_processor.get_image_decision(args, message)
            when GIVING_IMAGE
                @reports_processor.get_image(args, message)
            else
                case args[0]
                when START # START Command, start conversation, opens greeting message
                    @help_processor.start(message)
                when HELP # HELP Command, Display all possible Commands
                    @help_processor.help(message)
                when REPORT # REPORT Command, file a new Report and put it into the Database
                    @reports_processor.report(args, message)
                when FORMULAR_REPORT
                    @reports_processor.form_report(message)
                when COUNT # COUNT Command, Print the Number of filed Reports
                    @reports_processor.count(message)
                when ALL # ALL Command, Print all filed Reports
                    @reports_processor.all(message)
                when LAST # LAST Command, Print all filed Reports from the last 7 (or 'd', if specified) days
                    @reports_processor.last(args, message)
                when FEEDBACK
                    @feedback_processor.feedback(message)
                when ALL_FEEDBACK
                    @feedback_processor.all_feedback(message)
                else
                    @help_processor.unknown(message)
                end
            end
        end
    end     
end
