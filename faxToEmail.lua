-- -------------------------------------------------
-- -- Autor: Osvaldo da Silva Neto
-- -- Data: 01/08/2021
-- -- -------------------------------------------------

local os = require "os"
local smtp = require "socket.smtp"
local socket = require 'socket'
local ssl = require 'ssl'
local https = require 'ssl.https'
local ltn12 = require 'ltn12'


--parâmetros a configurar, depende de cada usuário
incomingfaxes = "/tmp/"
uuid = session:getVariable("uuid")
email = session:getVariable("email")
caller = session:getVariable("caller_id_number")
file = ''
tiff2pdfcmd = '/usr/bin/tiff2pdf'
email_from = "vofficeteste@gmail.com"
email_to = session:getVariable("email")
user = "vofficeteste"
password = "senha123#"


--Função responsável pelo recebimento do fax
function receiveFax()
    freeswitch.consoleLog("notice", "Receiving fax from "..caller.."\n")
    session:execute("playback", "silence_stream://2000")
    session:execute("rxfax", incomingfaxes.."rxfax-"..uuid..".tiff")
    freeswitch.consoleLog("notice", "Full receipt fax from "..caller.."\n")
end


--Função responsável pela converssão do arquivo .tiff para pdf
function convertTiff2Pdf()
    freeswitch.consoleLog("notice", "Convert file .tiff to pdf\n")
    freeswitch.consoleLog("notice", "rxfax-"..uuid..".tiff")
    erro = os.execute(tiff2pdfcmd.." "..incomingfaxes.."rxfax-"..uuid..".tiff -o "..incomingfaxes.."rxfax-"..uuid..".pdf")
    if erro > 0 then
        freeswitch.consoleLog("notice", "Erro "..erro.."\n")
    else
        freeswitch.consoleLog("notice", "Arquivo convertido com sucesso.\n")
    end
end


--Função responsável pela criação do socket
function sslCreate()
    local sock = socket.tcp()
    return setmetatable({
        connect = function(_, host, port)
            local r, e = sock:connect(host, port)
            if not r then return r, e end
            sock = ssl.wrap(sock, {mode='client', protocol='tlsv1'})
            return sock:dohandshake()
        end
    }, {
        __index = function(t,n)
            return function(_, ...)
                return sock[n](sock, ...)
            end
        end
    })
end


--Função responsável pelo envio de email
--Parâmetros: subject = assunto do email
function sendMessage(subject)
    print ('Iniciando envio de email')
    local msg = {
        headers = {
            from = "<"..email_from..">",
            to = 'email_to <'..email_to..'>',
            ["content-type"] = 'text/html',
            ["content-disposition"] = 'attachment; filename="'..incomingfaxes..'rxfax-'..uuid..'.pdf"',
            ["content-description"] = '"'..incomingfaxes..'rxfax-'..uuid..'.pdf"',
            ["content-transfer-encoding"] = "BASE64",
            subject = subject
        },
        body = ltn12.source.chain(
        ltn12.source.file(io.open(incomingfaxes.."rxfax-"..uuid..".pdf", "rb")),
        ltn12.filter.chain(
          mime.encode("base64"),
          mime.wrap()
          )
        )
    }
    local ok, err = smtp.send {
        from = '<'..email_from..'>',
        rcpt = '<'..email_to..'>',
        source = smtp.message(msg),
        user = user,
        password = password,
        server = 'smtp.gmail.com',
        port = 465,
        create = sslCreate
    }
    if not ok then
        freeswitch.consoleLog("notice", "Problemas no envio de email...\n")
    else
        freeswitch.consoleLog("notice", "Email enviado com sucesso...\n")
    end
end


freeswitch.consoleLog("notice", "Script faxToEmail.lua starting\n")
freeswitch.consoleLog("notice", "Receiving fax from "..caller.."\n")
freeswitch.consoleLog("notice", "UUID "..uuid.."\n")
freeswitch.consoleLog("notice", "email "..email.."\n")

if session:ready() then
    session:answer()
end

receiveFax()
convertTiff2Pdf()
sendMessage(subject, body)sendMessage("Recebimento de Fax")
