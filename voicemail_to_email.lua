-- -------------------------------------------------
-- -- Autor: Osvaldo da Silva Neto
-- -- Data: 06/08/2021
-- -- -------------------------------------------------


local os = require "os"
local smtp = require "socket.smtp"
local socket = require 'socket'
local ssl = require 'ssl'
local https = require 'ssl.https'
local ltn12 = require 'ltn12'

--conta do emil
email_from = "vofficeteste@gmail.com"
user = "vofficeteste"
password = "senha123#"

--variáveis capturadas e editadas
domain_name = session:getVariable("domain_name")
destination_number = session:getVariable("destination_number")
uuid = session:getVariable("uuid")
email_to = session:getVariable("email")
caller_id_number = session:getVariable("caller_id_number")
path_record = "/usr/local/freeswitch/storage/voicemail/default/"..domain_name.."/"..destination_number
comando_mv = "mv "..path_record.."/msg_* tmp/msg-"..uuid..".wav"
assunto = "Mensagem de Voz Originada de "..caller_id_number


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
            ["content-disposition"] = 'attachment; filename="/tmp/msg-'..uuid..'.wav"',
            ["content-description"] = '"msg-'..uuid..'.wav"',
            ["content-transfer-encoding"] = "BASE64",
            subject = subject
        },
        body = ltn12.source.chain(
        ltn12.source.file(io.open('/tmp/msg-'..uuid..'.wav', "rb")),
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


--movendo arquivo para diretório /tmp
erro = os.execute(comando_mv)

if erro > 0 then
    freeswitch.consoleLog("notice", "Erro ao mover o arquivo : erro "..erro.."\n")
else
    freeswitch.consoleLog("notice", "Arquivo movido para o diretório /tmp.\n")
end

sendMessage(assunto)
