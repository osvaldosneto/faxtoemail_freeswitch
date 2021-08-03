# -*- coding: utf-8 -*-
import sys
import os
import time
import string
import glob

from datetime import *
from freeswitch import *

import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email import encoders


today = date.today().strftime("%Y%m%d")
logfile = "/usr/local/freeswitch/log/rxfax_" + today + ".log"
incomingfaxes = '/tmp/'
tiff2pdfcmd = '/usr/bin/tiff2pdf'


def writeToLog(session,msg):
    global logfile
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    uuid = session.getVariable("uuid")
    consoleLog( "info", msg)
    towrite = now + " " + uuid + " " + msg + "\n"
    fh = open(logfile,"a")
    fh.write(towrite)
    fh.close()




def sendEmail(session, email):
    writeToLog(session,"Enviando email para " + email)


def handler(session, args):
    the_uuid = session.getVariable("uuid")
    the_email = session.getVariable("email")
    the_caller = session.getVariable("caller_id_number")
    writeToLog(session,"Recebendo Fax de " + the_caller)

    #recebendo fax
    session.answer()
    session.execute("playback", "silence_stream://2000")
    session.execute("rxfax", incomingfaxes + "rxfax-" + the_uuid + ".tiff")
    writeToLog(session,"Recebimento de Fax finalizado rxfax-" + the_uuid + ".tiff")

    # capturando arquivo .tiff gerado
    pages = glob.glob(incomingfaxes + "rxfax-" + the_uuid + "*.tiff")
    pages.sort()

    # convertendo .tiff to pdf
    writeToLog(session,"Convertendo arquivo *.tiff em pdf, número de páginas " + str(len(pages)))
    error = os.system(tiff2pdfcmd + " " + incomingfaxes + "rxfax-" + the_uuid + ".tiff -o " + incomingfaxes + "rxfax-" + the_uuid + ".pdf")
    if error != 0:
        writeToLog(session,"Problemas ao converter arquivo para PDF.")
    else:
        writeToLog(session,"Arquivo convertido com sucesso, " + "rxfax-" + the_uuid + ".pdf")
        sendEmail(session, the_email)
