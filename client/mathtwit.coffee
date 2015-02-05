###
 Copyright (c) 2015 yvt
 
 This file is part of MathTwit.
 
 MathTwit is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 MathTwit is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with MathTwit.  If not, see <http://www.gnu.org/licenses/>.
###

"use strict"

if @importScripts? and not @document?
    # ------------- WebWorker ------------------
    importScripts "mimetex.js"
    MathTwit_Generate = Module.cwrap('MathTwit_Generate',
        'number', ['string'])

    # allow reset of state
    backupBuffer = new Uint8Array(Module.HEAPU8.length)

    ready = false
    @MathTwit_Ready = () =>
        ready = true
        # warm up
        MathTwit_Generate "\\sin z = \\sum^{\\infty}_{n=0} \\frac{(-1)^n}{(2n+1)!} z^{2n+1}"
        backupBuffer.set Module.HEAPU8
        postMessage
            cmd: "ready"
        return

    needsReset = false
    resetVM = ->
        Module.HEAPU8.set backupBuffer
        return

    resetIfNeeded = ->
        if needsReset
            resetVM()
            needsReset = false
        return

    @onmessage = (e) =>
        msg = e.data
        switch msg.cmd
            when "render"
                code = msg.code
                token = msg.token
                if code.length > 0 and code.substr(code.length - 1, 1) == "\\"
                    code += " "
                resetIfNeeded()
                try 
                    ret = MathTwit_Generate code
                catch e
                    # VM crash! state might be corrupted
                    needsReset = true
                    postMessage
                        cmd: "render-done"
                        token: token
                        error: "VM crashed."
                    return

                if ret == 0
                    postMessage
                        cmd: "render-done"
                        token: token
                        error: "mimeTeX internal error."
                else
                    width = Module.getValue ret, "i32"
                    height = Module.getValue ret + 4, "i32"
                    numPixels = width * height
                    imgData = new ArrayBuffer(width * height * 4)
                    imgDataView = new Uint32Array(imgData)
                    srcData = Module.HEAPU8
                    ret += 8;
                    for i in [0 ... numPixels]
                        imgDataView[i] = ((255 - srcData[ret]) * 0x10101) | 0xff000000
                        ++ret

                    postMessage
                        cmd: "render-done"
                        token: token
                        width: width
                        height: height
                        data: new Uint8Array(imgData)
        return

else
    # ------------- Main Script ------------------
    LocalStorage =
        setItem: (key, value) ->
            try localStorage.setItem key, value
        getItem: (key) ->
            try return localStorage.getItem key
            return null
    $.easing.easeOut = (per) ->
        per = 1 - per
        per *= per
        per *= per
        return 1 - per
    animDuration = 300

    fastClick = (e, onclick) ->
        e.each ->
            el = $(@)
            el.click onclick if onclick?

            touchId = null
            startY = 0; startSize = 0
            boundsCheck = (e) ->
                offs = el.offset()
                e.pageX >= offs.left and e.pageY >= offs.top and
                e.pageX < offs.left + el.width() and e.pageY < offs.top + el.height()
            el.bind 'touchstart', (e) ->
                return if touchId?
                for touch in e.originalEvent.changedTouches
                    touchId = touch.identifier
                    el.addClass 'pressed'
                    try e.preventDefault()
                    break
                return
            el.bind 'touchmove', (e) ->
                return if not touchId?
                for touch in e.originalEvent.changedTouches when touch.identifier == touchId
                    el.toggleClass 'pressed', boundsCheck touch
                    try e.preventDefault()
                return
            el.bind 'touchend', (e) ->
                return if not touchId?
                for touch in e.originalEvent.changedTouches when touch.identifier == touchId
                    touchId = null
                    el.removeClass 'pressed'
                    if boundsCheck touch
                        onclick?()
                    break
                return
            el.bind 'touchcancel', (e) ->
                return if not touchId?
                for touch in e.originalEvent.changedTouches when touch.identifier == touchId
                    touchId = null
                    el.removeClass 'pressed'
                    break
                return


    # ------------- Menus ------------------
    Menus = do ->
        mainMenuActive = false
        userMenuActive = false
        tweetWindowActive = false

        faderActive = false

        init: ->
            fastClick $('#branding'), =>
                return if tweetWindowActive
                @setMainMenuActive not mainMenuActive
                return
            fastClick $('#user-dropdown'), =>
                return if tweetWindowActive
                @setUserMenuActive not userMenuActive
                return

            fastClick $('#fader'), =>
                @setMainMenuActive false
                @setUserMenuActive false
                return

            return
        update: ->
            faderNeeded = mainMenuActive or userMenuActive or tweetWindowActive
            if faderNeeded != faderActive
                if faderNeeded
                    $('#fader').stop().css display: 'block', opacity: 0
                    $('#fader').stop().animate opacity: 1, animDuration, 'swing'
                else
                    $('#fader').stop().animate opacity: 0, animDuration, 'swing', ->
                        $(@).css display: 'none'
                faderActive = faderNeeded
            return
        setMainMenuActive: (active) ->
            return if mainMenuActive == active
            mainMenuActive = active
            if active
                @setUserMenuActive false
            $('#mainMenu').stop().animate left: (if active then 0 else -210), animDuration, 'easeOut'
            $('#branding').toggleClass 'active', active
            @update()
            return
        setUserMenuActive: (active) ->
            return if userMenuActive == active
            userMenuActive = active
            if active
                @setMainMenuActive false
            $('#userMenu').stop().animate right: (if active then 0 else -310), animDuration, 'easeOut'
            $('#user-dropdown').toggleClass 'active', active
            @update()
            return
        setTweetWindowActive: (active) ->
            return if tweetWindowActive == active
            tweetWindowActive = active
            if active
                @setUserMenuActive false
                @setMainMenuActive false
            if active
                $('#tweet-window').stop().css
                    top: $(window).height()
                    display: 'block'
                $('#tweet-window').animate
                    top: 0, animDuration * 1.5, 'easeOut'
            else
                $('#tweet-window').stop().animate
                    top: $(window).height(), animDuration * 1.5, 'easeOut', ->
                        $(@).css display: 'none'
            @update()
            return
    Menus.init()

    # ------------- Twitter ------------------
    TwitterService = do ->
        accounts = []
        try
            ac = JSON.parse LocalStorage.getItem 'mathtwit-twitter-accounts'
            accounts = ac if ac instanceof Array

        $('#tweet-editor').val (LocalStorage.getItem 'mathtwit-tweet-text') ? ''
        onTweetTextChanged = ->
            LocalStorage.setItem 'mathtwit-tweet-text', $('#tweet-editor').val()
            return
        $('#tweet-editor').change onTweetTextChanged
        $('#tweet-editor').keyup onTweetTextChanged

        activeAccount = null
        activeImage = null
        activeSession = null
        accountElements = {} # account to tweet from

        updateUI = ->
            $('#user-dropdown').text (if accounts.length == 0 then "Sign In" else "Tweet")
            return

        saveAccounts = ->
            LocalStorage.setItem 'mathtwit-twitter-accounts', JSON.stringify(accounts)
            return

        makeAccountElement = (a) ->
            e = $('<li>')
            tweet = $('<button class="tweet">').text "Tweet"
            fastClick tweet, ->
                activeAccount = a
                showTweetWindow()
                return

            tweet.appendTo e
            signout = $('<button class="signout">').text "Sign Out"
            fastClick signout, ->
                if confirm "Are you sure to sign out @#{a.screen_name}?"
                    for aa, i in accounts
                        if aa.user_id == a.user_id
                            accounts.splice i, 1
                            break
                    e.remove()
                    delete accountElements[a.user_id]
                    updateUI()
                    saveAccounts()
            signout.appendTo e
            img = $('<img>').attr src: a.icon
            img.appendTo e
            name = $('<span class="screenname">').text "@" + a.screen_name
            name.appendTo e
            accountElements[a.user_id] = e
            return e
        accountList = $('#userMenu > ul')

        # initialize UI
        do ->
            for a in accounts
                makeAccountElement(a).appendTo(accountList)
            updateUI()

        signinWorking = false
        fastClick $('#signin'), =>
            return if signinWorking
            signinWorking = true
            origText = $('#signin-text').text()
            $('#signin-text').text "Please wait..."
            ondone = () -> 
                $('#signin-text').text origText
                signinWorking = false
            onfail = (msg) ->
                ondone()
                alert msg

            $.ajax
                url: "/tw/api.json"
                type: "POST"
                data:
                    action: "nonce"
                success: (data) =>
                    if data.error?
                        onfail(data.error)
                    else
                        ondone()
                        window.location.href = "/tw/auth?action=signin&nonce=#{data.nonce}"
                    return
                error: (err) =>
                    onfail "network error."
            return

        # login token is passed with hash
        checkHash = ->
            hash = window.location.hash
            return if hash.indexOf('#token=') != 0
            token = hash.substr(7)
            window.location.hash = '' # remove hash

            # already added?
            for a in accounts
                if a.token == token
                    return

            # query user info
            $.ajax
                url: "/tw/api.json"
                type: "POST"
                data:
                    action: "info"
                    token: token
                success: (data) =>
                    if data.error?
                        alert "failed to add Twitter account.\n\n#{data.error}"
                        return

                    a =
                        token: token
                        screen_name: data.screen_name
                        icon: data.icon
                        user_id: data.user_id
                    for existingAccount, j in accounts
                        if a.user_id == existingAccount.user_id
                            accountElements[a.user_id].remove()
                            delete accountElements[a.user_id]
                            accounts.splice j, 1
                            break
                    accounts.push a
                    makeAccountElement(a).appendTo(accountList)
                    updateUI()
                    saveAccounts()

                    return
                error: (err) =>
                    alert "failed to add Twitter account due to a network error."

            return

        fastClick $('#tweet-cancel'), ->
            closeTweetWindow()
            return

        closeTweetWindow = ->
            return if submitting
            Menus.setTweetWindowActive false
            activeAccount = null
            activeSession = null
            activeImage = null
            return

        showTweetWindow = ->
            activeImage = null
            session = activeSession = {}

            # wait for image to ready
            Renderer.fetchImage (img) ->
                return if activeSession != session
                activeImage = img
                if not img?
                    closeTweetWindow()
                    alert "Failed to render image."
                else
                    imge = $('#tweet-image-view > img')
                    imge[0].src = img.toDataURL()
                    $('#tweet-submit').css opacity: 1

                    width = img.width; height = img.height
                    width /= pixelRatio; height /= pixelRatio
                    maxWidth = $(window).width() - 60
                    if width > maxWidth
                        height *= maxWidth / width
                        width = maxWidth
                    imge.css width: width, height: height

                return

            $('#tweet-submit').css opacity: 0.5

            Menus.setTweetWindowActive true
            setTimeout (-> $('#tweet-editor').focus()), 100
            $('#tweet-from').text "@" + activeAccount.screen_name

            return

        submitting = false
        fastClick $('#tweet-submit'), ->
            return unless activeImage? and 
                activeAccount? and not submitting

            origText = $('#tweet-submit').text()
            $('#tweet-submit').text "Tweeting..."
            $('#tweet-submit, #tweet-cancel').css opacity: 0.5

            submitting = true
            ondone = ->
                submitting = false
                $('#tweet-submit').text origText
                $('#tweet-submit, #tweet-cancel').css opacity: 1

            # extract base64 of image
            dataURL = activeImage.toDataURL()
            idx = dataURL.indexOf ','
            if idx < 0
                ondone()
                alert "Failed to extract image data. " + 
                "Please report this error and the name of your web browser to the developer.\n\n" +
                "debug info: #{dataURL.substr(0, 50)}"
                return


            $.ajax
                url: "/tw/api.json"
                type: "POST"
                data:
                    action: "tweet"
                    token: activeAccount.token
                    text: $('#tweet-editor').val()
                    image: dataURL.substr(idx + 1)
                success: (data) =>
                    ondone()
                    if data.error?
                        alert "failed to tweet.\n\n#{data.error}"
                        return

                    Menus.setTweetWindowActive false
                    setTimeout (-> $('#tweet-editor').val(''); onTweetTextChanged()), 600


                    return
                error: (err) =>
                    ondone()
                    alert "failed to tweet due to a network error."


            return

        $(window).bind 'hashchange', ->
            checkHash()
            return
        checkHash()

        return

    # ------------- Rendering ------------------
    Renderer = do ->
        worker = null

        working = null
        pending = null
        readyToRender = false

        lastImage = null
        getLastImageHandlers = []

        checkPending = ->
            return unless readyToRender
            if pending?
                work = pending
                work.timer = setTimeout(() ->
                    work.callback null, "Timed out."
                    restartWorker()
                , 10000)
                worker.postMessage
                    cmd: "render"
                    code: pending.text
                    token: pending.token
                working = work
                pending = null
                readyToRender = false
            return

        restartWorker = ->
            if worker?
                worker.onmessage = null
                worker.terminate()
            readyToRender = false
            working = null
            worker = new Worker("mathtwit.js")

            worker.onmessage = (e) =>
                msg = e.data
                switch msg.cmd
                    when "ready"
                        readyToRender = true
                        checkPending()

                    when "render-done"
                        token = msg.token

                        work = working
                        working = null
                        readyToRender = true
                        checkPending()

                        clearTimeout work.timer

                        if msg.error?
                            lastImage = null
                            work.callback null, msg.error
                        else
                            width = msg.width
                            height = msg.height
                            data = msg.data

                            canvas = document.createElement 'canvas'
                            canvas.width = width
                            canvas.height = height
                            ctx = canvas.getContext '2d'
                            id = ctx.createImageData width, height
                            id.data.set data
                            ctx.putImageData id, 0, 0

                            lastImage = canvas
                            work.callback canvas, null

                        if working == null
                            handlers = getLastImageHandlers
                            getLastImageHandlers = []
                            for handler in handlers
                                handler lastImage



        restartWorker()
        
        fetchImage: (callback) ->
            if working == null
                setTimeout (-> callback lastImage), 0
            else
                getLastImageHandlers.push callback
        renderText: (text, callback) ->
            work = 
                token: {}
                text: text
                callback: callback
                timer: null
            pending = work
            checkPending()

            return 
    # End of Renderer

    currentImageSize = [1, 1]
    editorSize = parseFloat(LocalStorage.getItem("mathtwit-editorSize") ? 80)
    if isNaN editorSize
        editorSize = 80
    handleEventListener = $('#handleEventListener')

    pixelRatio = 1
    pixelRatio = window.devicePixelRatio if window.devicePixelRatio?
    pixelRatio = window.webkitDevicePixelRatio if window.webkitDevicePixelRatio?
    pixelRatio = window.mozDevicePixelRatio if window.mozDevicePixelRatio?
    pixelRatio = window.oDevicePixelRatio if window.oDevicePixelRatio?
    pixelRatio = window.msDevicePixelRatio if window.msDevicePixelRatio?

    # allow user to change size of editor
    setEditorSize = (value) ->
        editorSize = value
        doLayout()
        LocalStorage.setItem "mathtwit-editorSize", editorSize
        return

    handleEventListener.mousecapture
        down: (e, data) ->
            data.startSize = editorSize
            data.startY = e.pageY
            try e.preventDefault()
            return
        move: (e, data) ->
            setEditorSize e.pageY - data.startY + data.startSize
            try e.preventDefault()
            return
    do ->
        touchId = null
        startY = 0; startSize = 0
        handleEventListener.bind 'touchstart', (e) ->
            return if touchId?
            for touch in e.originalEvent.changedTouches
                touchId = touch.identifier
                startSize = editorSize
                startY = touch.pageY
                try e.preventDefault()
                break
            return
        handleEventListener.bind 'touchmove', (e) ->
            return if not touchId?
            for touch in e.originalEvent.changedTouches when touch.identifier == touchId
                setEditorSize touch.pageY - startY + startSize
                try e.preventDefault()
            return
        handleEventListener.bind 'touchend', (e) ->
            return if not touchId?
            for touch in e.originalEvent.changedTouches when touch.identifier == touchId
                touchId = null
                break
            return
        handleEventListener.bind 'touchcancel', (e) ->
            return if not touchId?
            for touch in e.originalEvent.changedTouches when touch.identifier == touchId
                touchId = null
                setEditorSize startSize
                break
            return



    doLayout = (initial = false) ->

        bodyW = $('#body').width()
        bodyH = $('#body').height()

        # restrict editor size
        minSize = 20
        maxSize = bodyH - 50
        editorSize = Math.min editorSize, maxSize
        editorSize = Math.max editorSize, minSize

        # set editor size
        $('#editor').css height: editorSize
        resultView = $('#resultView')
        resultViewHeight = bodyH
        if initial
            resultView.css
                top: bodyH
                height: resultViewHeight
                display: 'block'
            resultView.animate
                top: editorSize,
                500, 'easeOut'
        else
            resultView.stop().css
                top: editorSize
                height: resultViewHeight
        handleEventListener.css top: editorSize

        # Layout image
        ie = $('#image')
        handleSize = 10
        rvW = bodyW
        rvH = bodyH - editorSize - handleSize

        [imgW, imgH] = currentImageSize
        imgW /= pixelRatio
        imgH /= pixelRatio

        rvAvailW = Math.max rvW - 40, 1
        rvAvailH = Math.max rvH - 40, 1

        if imgW > rvAvailW
            imgH *= rvAvailW / imgW
            imgW = rvAvailW
        if imgH > rvAvailH
            imgW *= rvAvailH / imgH
            imgH = rvAvailH

        ie.css 
            width: imgW, height: imgH, 
            left: (rvW - imgW) / 2, top: handleSize + 20

        return

    example = "\\sin z = \\sum^{\\infty}_{n=0} \\frac{(-1)^n}{(2n+1)!} z^{2n+1}"
    $('#editor').attr 'placeholder', example

    doRender = ->
        text = $('#editor').val()
        if text == ""
            text = example

        Renderer.renderText text, (canvas, error) ->
            ie = $('#image')
            ev = $('#errorView')
            if canvas?
                ie[0].src = canvas.toDataURL()
                ie[0].width = canvas.width
                ie[0].height = canvas.height
                currentImageSize = [canvas.width, canvas.height]
                ie.css display: 'block'
                ev.css display: 'none'
                doLayout()
            else
                ie.css display: 'none'
                ev.css display: 'block'
                $('#errorBody').text error


            return
        return

    fastClick $('#clear-all'), ->
        if confirm "Are you sure you want to start over?"
            $('#editor').val ""
            onChange()
            return

    $('#editor').val LocalStorage.getItem("mathtwit-text") ? ""

    onChange = () ->
        LocalStorage.setItem "mathtwit-text", $('#editor').val()
        doRender()
        return
    $("#editor").change onChange
    $('#editor').bind 'keyup', ->
        setTimeout onChange, 0
    $('#editor').bind 'input', ->
        setTimeout onChange, 0
    doLayout(true)
    setTimeout doRender, 500
    $(window).resize -> doLayout()

    return


