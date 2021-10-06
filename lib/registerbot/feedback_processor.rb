require './lib/registerbot/basic_processor'
require 'telegram/bot'
require 'sequel'

class Feedback_processor < Basic_processor
    Feedback_Inputs = Struct.new(:state, :rating, :tips)
    def initialize(bot, feedback_db)
        super(bot)
        @feedback = feedback_db
    end

    def format_feedback(res)
        feedbacks = []
        res.each { |feedback|
            feedbacks << "Feedback Nummer #{feedback[:id]}: Bewertung: #{feedback[:rating].inspect}, Anmerkungen: #{feedback[:tips].inspect}"
        }
        feedbacks.join("\n--------\n")
    end

    def all_feedback(message)
        send_message("Alle Feedbacks bisher lauten:\n\n#{format_feedback(@feedback.all)}", message)
    end

    def feedback(message)
        @user_state[message.chat.id] = Feedback_Inputs.new(RATING, nil, nil)
        rating = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard:[%w(1 2 3 4 5)], resize_keyboard: true)
        send_message_with_markup("Auf einer Skala von 1 (sehr schlecht) bis 5 (sehr gut), wie gefalle ich dir?", message, rating)
    end

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
            feedback()
            return
        end
        @user_state[message.chat.id] = Feedback_Inputs.new(ASKED_FOR_TIPS, answer, nil)
        decision = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard:[%w(Ja Nein)], resize_keyboard: true)
        send_message_with_markup("Möchtest du mir noch Verbesserungsvorschläge, Wünsche oder Fehlerberichte geben?", message, decision)
    end

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
        end
    end

    def get_tips(message)
        @user_state[message.chat.id][:tips] = message.text
        @feedback.insert(:rating => @user_state[message.chat.id].rating, :tips => @user_state[message.chat.id].tips)
        @user_state.delete(message.chat.id)
        send_message("Vielen Dank für deine Tipps! Dank dir kann ich weiterhin mein bestes geben!", message)
    end
end