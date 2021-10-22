# The possible commands.The user can always only execute one of them at a time.

# The user started the bot for the first time (automatically sends '/start') or requests to display the greeting message
START = '/start'

# The user requests to see all possible commands
HELP = '/hilfe'                

# The user requests the total amount of reports the bot has stored
COUNT = '/anzahl'               

# The user reports one or more incidents
REPORT = '/sammelmeldung'       

# The user requests to see all stored reports
ALL = '/all'                    

# The user requests to see all reports of the last days
LAST = '/letzte'                

# The user requests to give feedback on the bot
FEEDBACK = '/feedback'          

# The user requests to see all feedback given to the bot
ALL_FEEDBACK = '/all_feedback'  

# The user requests to make a step-by-step guided report
FORMULAR_REPORT = '/meldung'    

# The user requests to take a closer look at a report
INSPECT = '/zeige'              

# The user requests to cancel the current process of reporting
CANCEL = '/cancel'              



# The possible `user_state` states. The user can always only be in one of those states. 
# There is no 'idle' state, because if user is in none of these states, there is no use in keeping their `chat_id` in the Bots memory for nothing 

# The user is currently rating the bot
RATING = 1              

# The user has been asked to give textual feedback and is currently deciding whether they want to do so
ASKED_FOR_TIPS = 2      

# The user is currently writing textual feedback
GIVING_TIPS = 3         

# The user is currently reporting the date of an incident
REPORTING_DATE = 4      

# The user is currently reporting the place of an incident
REPORTING_PLACE = 5     

# The user is currently reporting the actions happening during an incident
REPORTING_ACTIVITY = 6  

# The user has been asked for contact information and is currently deciding whether to give them to the bot or not
ASKED_FOR_CONTACTS = 7  

# The user is currently giving the Bot their contact information
GIVING_CONTACTS = 8     

# The user has been asked for an image of the incident and is currently deciding whether to give them to the bot or not
ASKED_FOR_IMAGE = 9     

# The user is currently sending an image of on incident
GIVING_IMAGE = 10       


# The possible answers to a decision `Telegram::Bot::Types::ReplyKeyboardMarkup`

# A positive Answer
YES = "Ja"

# A negating Answer
NO = "Nein"