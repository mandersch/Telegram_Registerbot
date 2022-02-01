require 'telegram/bot'
require 'concurrent'

# The superclass for all used content processors. Defines the most basic functionality for all processors, such as sending messages.
class Basic_processor

    # Makes the user_state of this class and all subclasses accessible to the bot from outside the processors
    # @note This method may modify our application state 
    attr_reader :user_state

    # Creates a new `Basic_processor` instance
    #
    # The `user_state` instance variable is only ever set to an empty `Hash`, as this class contains no functionality based on the `user_state`
    # @param bot [Telegram::Bot::Client] the actual bot communicating with the telegram bot-API
    def initialize(bot, logger)
        @logger = logger
        @user_state = Concurrent::Hash.new()
        @bot = bot
    end

    # Send a Message as a reply to a user's message by letting the bot call the Telegram Bot-API
    #
    # @param text [String] The answer text to send to the user
    # @param message [Telegram::Bot::Types::Message] the original message received by the bot, which should be answered to
    def reply(text, message)
        @logger.info("Sending reply message: text=#{text.inspect} to uid: #{message.from.id}")
        @bot.api.send_message(chat_id: message.chat.id, text: text, reply_to_message: message)    
    end

    # Send a message to a user by letting the bot call the Telegram Bot-API
    #
    # @param text [String] The answer text to send to the user
    # @param message [Telegram::Bot::Types::Message] the original message received by the bot, used to identify the correct `chat_id` to respond to
    def send_message(text, message)
        @logger.info("Sending message: text=#{text.inspect} to uid: #{message.from.id}")
        @bot.api.send_message(chat_id: message.chat.id, text: text)    
    end

    # Send a message to a user by letting the bot call the Telegram Bot-API
    #
    # @param text [String] The answer text to send to the user
    # @param message [Telegram::Bot::Types::Message] the original message received by the bot, used to identify the correct `chat_id` to respond to
    # @param markup [Telegram::Bot::Types::ReplyKeyboardMarkup] the markup to be used on a Message e.g. a custom Keyboard, a forced reply, or a revoke-of-custom-keyboard
    def send_message_with_markup (text, message, markup)
        @logger.info("Sending message containing a Keyboard-markup: text=#{text.inspect} to uid: #{message.from.id}")
        @bot.api.send_message(chat_id: message.chat.id, text: text, reply_markup: markup)
    end
end