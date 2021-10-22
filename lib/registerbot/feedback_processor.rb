require './lib/registerbot/basic_processor'
require 'telegram/bot'
require 'sequel'

# A Processor for `message`s that revolve around the user giving feedback or asking to view older feedbacks.
#   Inherits from `Basic_processor` class (see #Basic_processor)
class Feedback_processor < Basic_processor
    
    # The Struct behind the `user_state`, contains the state, the rating when given, and the textual feedback when given
    #   After the entrys are stored in the Database, the `user_state` is set back to nil
    Feedback_Inputs = Struct.new(:state, :rating, :tips)

    # Creates a new `Feedback_processor` instance.
    #
    # @note the initialize method calls the initialize of the superclass `Basic_processor` (see #Basic_processor)
    # @param bot [Telegram::Bot::Client] the actual bot communicating with the telegram bot-API
    # @param feedback_db [Sequel::Dataset] the Database table to store all received feedbacks in, requires the fields 'id', 'rating' and 'tips'
    # @note feedback_db requires specific fields! Those are: 'primary_key :id', 'String :rating', 'String :tips'
    def initialize(bot, feedback_db)
        super(bot)
        @feedback = feedback_db
    end

    # Formats the Array of Hashes retrieved from a Dataset/Databse query into a more readable Format
    #
    # @param res [Array] an Array of Hashes as received by a Database query. Hashes must contain the fields of the feedback database 'id', 'rating' and 'tips'
    # @note res is required to contain specific fields! Those are: 'primary_key :id', 'String :rating', 'String :tips'
    def format_feedback(res)
        feedbacks = []
        res.each { |feedback|
            feedbacks << "Feedback Nummer #{feedback[:id]}: Bewertung: #{feedback[:rating].inspect}, Anmerkungen: #{feedback[:tips].inspect}"
        }
        feedbacks.join("\n--------\n")
    end

    # Return all feedbacks found in the Database
    #
    # @param message [Telegram::Bot::Types::Message] the original message received from the user asking for the feedbacks
    # @note this method calls `format_feedback()` method (see #format_feedback) to make the query result readable for the user
    def all_feedback(message)
        send_message("Alle Feedbacks bisher lauten:\n\n#{format_feedback(@feedback.all)}", message)
    end

    # Start the dialog to receive a user feedback
    #
    # @param message [Telegram::Bot::Types::Message] the original message received from the user asking to give feedback
    # @note as this message sets the `user_state` to 'RATING', the next message received in the chat MUST contain the rating
    #   and is directed to the `get_rating()` method (see #get_rating)
    # @note This method may modify our application state 
    def feedback(message)
        @user_state[message.chat.id] = Feedback_Inputs.new(RATING, nil, nil)
        # Define the possible Ratings (1-5), can also be changed up later, but requires adjustment to `get_rating` method in that case
        rating = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard:[%w(1 2 3 4 5)], resize_keyboard: true)
        send_message_with_markup("Auf einer Skala von 1 (sehr schlecht) bis 5 (sehr gut), wie gefalle ich dir?", message, rating)
    end

    # Get the rating sent by the user after querying them for a rating and ask them to give a textual feedback
    #
    # @param answer [String] usually the first word of the message text, containg the rating. If not a number from 1 to 5 the bot will recall the
    #   `feedback()` method, to once again query the user for a valid answer
    # @param message [Telegram::Bot::Types::Message] the original message received from the user giving the rating
    # @note as this message sets the `user_state` to 'ASKED_FOR_TIPS', the next message received in the chat MUST contain the an answer (yes or no)
    #   and is directed to the `get_feedback_decision()` method (see #get_feedback_decision)
    # @note This method may modify our application state 
    def get_rating(answer, message)
        case answer
        when "1"
            send_message("Oh, es tut mir Leid, dass ich deine Erwartungen nicht erfüllen konnte. Mit etwas Feedback kann ich aber betimmt besser werden!", message)
        when "2"
            send_message("Ohje, da gibt es wohl noch einiges für mich zu tun, um besser zu werden. Gib mir doch ein paar Tips damit meine Entwicklung auch wirklich in die richtige Richtung geht.", message)
        when "3"
            send_message("Na gut, da ist wohl noch etwas Luft nach oben für mich. Mit ein bisschen Feedback wird das in Zukunft bestimmt besser.", message)
        when "4"
            send_message("Es freut mich, dass ich dir so gut gefalle. Lass mir doch ein bisschen Feedback da um auch die letzten Probleme noch zu verbessern.", message)
        when "5"
            send_message("Wow, Dankeschön! Freut mich, dass ich dir so gut gefalle. Wenn du Lust hast, lass mir doch trotzdem ein kurzes Feedback da.", message)
        else
            send_message("Das ist leider keine gültige Bewertung, bitte schick mir eine Zahl von 1 bis 5.", message)
            feedback(message)
            return
        end
        @user_state[message.chat.id] = Feedback_Inputs.new(ASKED_FOR_TIPS, answer, nil)
        decision = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard:[%w(Ja Nein)], resize_keyboard: true)
        send_message_with_markup("Möchtest du mir noch Verbesserungsvorschläge, Wünsche oder Fehlerberichte geben?", message, decision)
    end

    # Get the answer sent by the user, whether they want to give textual feedback or not and if yes, query them for the textual feedback,
    #   otherwise store the rating in the Database. If neither yes or no is answered, query the user again.
    #   Since no `Telegram::Bot::Types::ReplyKeyboardRemove` is sent with the new query, the old yes/no markup should still be in place.
    #
    # @param answer [String] usually the first word of the message text, containg the answer (yes or no). 
    #   If not a yes or no, the bot will once again query the user for a valid answer
    # @param message [Telegram::Bot::Types::Message] the original message received from the user giving the answer
    # @note as this message sets the `user_state` to 'GIVING_TIPS' when yes is answered, the next message received in the chat MUST contain the textual feedback
    #   and is directed to the `get_tips()` method (see #get_tips)
    # @note as this message deletes the `user_state` when no is answered the next message received in the chat can contain any command again
    # @note This method may modify our application state 
    def get_feedback_decision(answer, message)
        hide = Telegram::Bot::Types::ReplyKeyboardRemove.new(remove_keyboard: true, selective: nil)
        case answer
        when YES
            @user_state[message.chat.id][:state] = GIVING_TIPS
            send_message_with_markup("Was würdest du dir von mir wünschen? Was gefällt dir gut/schlecht?", message, hide)
        when NO
            @feedback.insert(:rating => @user_state[message.chat.id].rating, :tips => "")
            @user_state.delete(message.chat.id)
            send_message_with_markup("In Ordnung.", message, hide)
        else
            send_message("Das habe ich nicht verstanden. Möchtest du mir noch Verbesserungsvorschläge, Wünsche oder Fehlerberichte geben?", message)
        end
    end

    # Get the textual feedback written by the user and store it in the Database. 
    #
    # @param message [Telegram::Bot::Types::Message] the original message received from the user giving the textual feedback
    # @note as this message deletes the `user_state` the next message received in the chat can contain any command again
    # @note This method may modify our application state 
    def get_tips(message)
        @user_state[message.chat.id][:tips] = message.text
        @feedback.insert(:rating => @user_state[message.chat.id].rating, :tips => @user_state[message.chat.id].tips)
        @user_state.delete(message.chat.id)
        send_message("Vielen Dank für deine Tipps! Dank dir kann ich weiterhin mein bestes geben!", message)
    end
end