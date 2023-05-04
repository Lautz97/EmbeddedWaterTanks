import json
import logging
import paho.mqtt.client as mqtt

# pip install python-telegram-bot==13.15
import telegram
from telegram.ext import Updater, CommandHandler, MessageHandler, Filters

TOKEN = "TOKEN"


class commandItem:
    def __init__(self, c, d, f):
        self.cmd = c
        self.desc = d
        self.fun = f


idListToUpdate = []

### MQTT
mqtt_server = "node02.myqtthub.com"
mqtt_user = "receiver"
mqtt_Id = "Receiver"
mqtt_pwd = "password"

mqtt_server_port = 1883
mqtt_channel_sub = "prj_upstream"
mqtt_channel_pub = "prj_dwnstream"


# MQTT client callbacks
def on_connect(client, userdata, flags, rc):
    print("Connected to MQTT broker with result code " + str(rc))
    client.subscribe(mqtt_channel_sub)


def on_message(client, userdata, msg):
    print(
        "MQTT message received: " + msg.topic + " " + str(msg.payload.decode("utf-8"))
    )
    # Forward the message to Telegram
    for id in idListToUpdate:
        bot.send_message(
            chat_id=id,
            text="MQTT message received: "
            + msg.topic
            + " "
            + str(msg.payload.decode("utf-8")),
        )


### MQTT

# Enable logging
logging.basicConfig(
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s", level=logging.INFO
)

logger = logging.getLogger(__name__)


# Define a few command handlers. These usually take the two arguments update and
# context. Error handlers also receive the raised TelegramError object in error.
def start(update, context):
    """Send a message when the command /start is issued."""
    update.message.reply_text("Hi!")
    context.bot.send_message(
        chat_id=update.effective_chat.id,
        text="Please send me the command '/update_me' to start receiveing notifications on the state of your water tanks!",
    )
    context.bot.send_message(
        chat_id=update.effective_chat.id,
        text="Use the command '/remove_me' to stop receiveing notifications",
    )


def mqtt_state(update, context):
    """Send a message when the command /start is issued."""
    update.message.reply_text("Checking...")
    context.bot.send_message(
        chat_id=update.effective_chat.id,
        text="The MQTT Client appears to be: " + "on"
        if mqtt_client.is_connected()
        else "off",
    )


def update_me(update, context):
    """Send a message when the command /start is issued."""
    if idListToUpdate.count(update.message.chat.id) > 0:
        update.message.reply_text("You are already in the list of subscribers!")
    else:
        while idListToUpdate.count(update.message.chat.id) <= 0:
            idListToUpdate.append(update.message.chat.id)
            update.message.reply_text("You have been added to the list of subscribers!")

    print(idListToUpdate)


def remove_me(update, context):
    """Send a message when the command /start is issued."""
    if idListToUpdate.count(update.message.chat.id) <= 0:
        update.message.reply_text("You were not in the list of subscribers!")
    else:
        while idListToUpdate.count(update.message.chat.id) > 0:
            idListToUpdate.remove(update.message.chat.id)
            update.message.reply_text(
                "You have been removed from the list of subscribers!"
            )
    print(idListToUpdate)


def help(update, context):
    """Send a message when the command /help is issued."""
    update.message.reply_text("Need help?")
    context.bot.send_message(
        chat_id=update.effective_chat.id,
        text="Please send me the command '/update_me' to start receiveing notifications on the state of your water tanks!",
    )
    context.bot.send_message(
        chat_id=update.effective_chat.id,
        text="Use the command '/remove_me' to stop receiveing notifications",
    )
    if idListToUpdate.count(update.message.chat.id) > 0:
        context.bot.send_message(
            chat_id=update.effective_chat.id, text="You are in the list of subscribers!"
        )
    else:
        context.bot.send_message(
            chat_id=update.effective_chat.id,
            text="You are not in the list of subscribers!",
        )


def debub_print(update, context):
    """Send a message when the command /cmd1 is issued."""
    print(update.message.text)
    # upd_text = str(update)
    # upd_parsed = json.loads(upd_text.replace("'", '"'))
    # print(upd_parsed)
    # print("\n")
    # print(json.dumps(upd_parsed, indent=4))
    print(update)
    update.message.reply_text("Ok! your chat id is: " + str(update.message.chat.id))


def error(update, context):
    """Log Errors caused by Updates."""
    logger.warning('Update "%s" caused error "%s"', update, context.error)


def message(update, context):
    # Forward the message to MQTT
    mqtt_client.publish(mqtt_channel_pub, update.message.text)
    context.bot.send_message(
        chat_id=update.effective_chat.id,
        text="Telegram message forwarded to MQTT: " + update.message.text,
    )


commands = [
    commandItem("start", "Start working with the bot", start),
    commandItem("help", "Ask for help", help),
    # commandItem(
    #     "print_debug",
    #     "Send to console some gibberish for debugging",
    #     debub_print,
    # ),
    commandItem("update_me", "Update me on the state of the tanks", update_me),
    commandItem("remove_me", "Remove me from the subscriber list", remove_me),
    commandItem("mqtt_state", "Check the connection to mqtt", mqtt_state),
]

bot = telegram.Bot(token=TOKEN)
mqtt_client = mqtt.Client(mqtt_Id)


def main():
    """Start the bot."""
    print("Starting...")

    # Create the Updater and pass it your bot's token.
    # Make sure to set use_context=True to use the new context based callbacks
    # Post version 12 this will no longer be necessary
    updater = Updater(token=TOKEN, use_context=True)

    # Get the dispatcher to register handlers
    dp = updater.dispatcher

    botCommands = []
    for i in commands:
        dp.add_handler(CommandHandler(command=i.cmd, callback=i.fun))
        botCommands.append((i.cmd, i.desc))

    bot.setMyCommands(botCommands)

    dp.add_handler(MessageHandler(filters=Filters.text, callback=message))

    # log all errors
    dp.add_error_handler(error)

    # Start the Bot
    updater.start_polling()

    mqtt_client.username_pw_set(mqtt_user, mqtt_pwd)
    mqtt_client.on_connect = on_connect
    mqtt_client.on_message = on_message
    mqtt_client.connect(mqtt_server, mqtt_server_port, 60)

    mqtt_client.loop_forever()

    # Run the bot until you press Ctrl-C or the process receives SIGINT,
    # SIGTERM or SIGABRT. This should be used most of the time, since
    # start_polling() is non-blocking and will stop the bot gracefully.
    updater.idle()


if __name__ == "__main__":
    main()
