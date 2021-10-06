require 'telegram/bot'

class Basic_processor
    attr_reader :user_state
    def initialize(bot)
        @user_state = Hash.new()
        @bot = bot
    end

    def reply(text, message)
        @bot.api.send_message(chat_id: message.chat.id, text: text, reply_to_message: message)    
    end

    def send_message(text, message)
        @bot.api.send_message(chat_id: message.chat.id, text: text)    
    end

    def send_message_with_markup (text, message, markup)
        @bot.api.send_message(chat_id: message.chat.id, text: text, reply_markup: markup)
    end
end