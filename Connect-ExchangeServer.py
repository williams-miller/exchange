'''
DESCRIPTION
Connect to exchange server and read emails.
'''
from exchangelib import DELEGATE, Account, Credentials, Configuration

def configuration(server,credentials):
    config = Configuration(server=server, credentials=credentials)
    return config

def create_connection(config,email_address):
    connection = Account(
        primary_smtp_address = email_address,
        config = config,
        autodiscover = False,
        access_type = DELEGATE
    )   
    return connection

def read_email(config,message_numbers):
    for item in config.inbox.all().order_by('-datetime_received')[:message_numbers]:
        print(item.subject, item.body, item.attachments)


server = '104.243.43.115'
email_address = 'laitcasm\sys-admin'
credentials = Credentials(
    username = email_address, 
    password = 'adminadmin!'
)

config = configuration(server,credentials)
connection = create_connection(config,email_address)
