'''
DESCRIPTION
Send an email.
'''

from exchangelib import Message, Mailbox

recipients_email1  = ''
recipients_email2 = ''
cc_recipients_email1 = ''
cc_recipients_email2 = ''
bcc_recipients_email1 = ''
email = Message(
    account='laitcams\sys-admin',
    subject='Daily motivation',
    body='All bodies are beautiful',
    to_recipients=[
        Mailbox(email_address=recipients_email1),
        Mailbox(email_address=recipients_email2),
    ],
    # Simple strings work, too
    cc_recipients=[cc_recipients_email1, cc_recipients_email2],
    bcc_recipients=[
        Mailbox(email_address=bcc_recipients_email1),
    ]  
)
email.send()
