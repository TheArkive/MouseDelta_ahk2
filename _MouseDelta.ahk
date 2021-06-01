; ===============================================
; === Example ===================================
; ===============================================

; g := Gui("+AlwaysOnTop 0x2000000","MouseDelta") ; 0x2000000 = double buffering, less flicker of controls
; g.OnEvent("close",gui_close)

; ctl := g.Add("Edit","w300 h150 vMyEdit ReadOnly","Move the mouse or click a button")
; ctl.SetFont("s10","Consolas")
; g.Show()


; gui_close(g) {
    ; ExitApp
; }

; md := MouseDelta("MouseEvent")

; md.SetState(1)

; MouseEvent(MouseID, obj) { ; parameters for callback function
    ; Global g
    
    ; msg := "x/y: " obj.x ", " obj.y "`r`n"  ; all obj propertes are displayed here
         ; . "x/y Delta: " obj.xD " / " obj.yD "`r`n"
         ; . " LButton: " obj.b1 "`r`n"
         ; . " RButton: " obj.b2 "`r`n"
         ; . " MButton: " obj.b3 "`r`n"
         ; . "XButton1: " obj.b4 "`r`n"
         ; . "XButton2: " obj.b5 "`r`n"
         ; . "Wheel: " obj.mw
    
    ; g["MyEdit"].value := msg
; }

; ======================================================================
; MouseDelta class
;   Originally by evilC writen for AHK v1
;   https://www.autohotkey.com/boards/viewtopic.php?f=19&t=10159&hilit=mousedelta
; ======================================================================
Class MouseDelta {
    State := 0
    __New(callback) {
        this.MouseMovedFn := ObjBindMethod(this,"MouseMoved")
        this.Callback := callback
    }

    Start() {
        static DevSize := 8 + A_PtrSize, RIDEV_INPUTSINK := 0x00001100 ; Register mouse for WM_INPUT messages.
        
        RAWINPUTDEVICE := Buffer(DevSize)
        oGui := Gui()           ; WM_INPUT needs a hwnd to route to, so get the hwnd of the AHK Gui.
        oGui.Opt("ToolWindow")
        oGui.Show()             ; window must be shown apparently ...
        this.gui := oGui
        
        NumPut("UShort",1,"UShort",2,"UInt",RIDEV_INPUTSINK,"UPtr",oGui.hwnd,RAWINPUTDEVICE) ; populate RAWINPUTDEVICE
        this.RAWINPUTDEVICE := RAWINPUTDEVICE
        result := DllCall("RegisterRawInputDevices", "UPtr", RAWINPUTDEVICE.Ptr, "UInt", 1, "UInt", DevSize )
        
        OnMessage(0x00FF, this.MouseMovedFn)
        this.State := 1
        return this    ; allow chaining
    }
    
    Stop() {
        static RIDEV_REMOVE := 0x00000001
        static DevSize := 8 + A_PtrSize
        OnMessage(0x00FF, this.MouseMovedFn, 0)
        RAWINPUTDEVICE := this.RAWINPUTDEVICE
        NumPut("UInt",RIDEV_REMOVE,RAWINPUTDEVICE,4)
        DllCall("RegisterRawInputDevices", "UPtr", RAWINPUTDEVICE.Ptr, "UInt", 1, "UInt", DevSize )
        this.gui.Destroy()
        this.State := 0
        return this    ; allow chaining
    }
    
    SetState(state) {
        if (state && !this.State)
            this.Start()
        else if (!state && this.State)
            this.Stop()
        return this    ; allow chaining
    }

    Delete() {
        this.Stop()
        this.MouseMovedFn := ""
    }
    
    MouseMoved(wParam, lParam, msg, hwnd) { ; Called when the mouse moved and get raw input stats.
        Critical
        static DeviceSize := 2 * A_PtrSize, iSize := 0, sz := 0
        Static pcbSize:=8+2*A_PtrSize, offsets := {x: (20+A_PtrSize*2), y: (24+A_PtrSize*2)}, uRawInput 
        Static b1 := 0, b2 := 0, b3 := 0, b4 := 0, b5 := 0, mw := 0
        
        static axes := {x: 1, y: 2}
        
        header := Buffer(pcbSize, 0) ; Get hDevice from RAWINPUTHEADER to identify which mouse this data came from
        If !DllCall("GetRawInputData", "UPtr", lParam, "uint", 0x10000005
                                     , "UPtr", header.ptr, "Uint*", &pcbSize, "Uint", pcbSize)
            Return 0
        ThisMouse := NumGet(header, 8, "UPtr")
        
        if (!iSize) { ; Find size of rawinput data - only needs to be run the first time.
            r := DllCall("GetRawInputData", "UInt", lParam, "UInt", 0x10000003
                                          , "UPtr", 0, "UInt*", &iSize, "UInt", 8 + (A_PtrSize * 2))
            uRawInput := Buffer(iSize)
        }
        sz := iSize    ; param gets overwritten with # of bytes output, so preserve iSize
        r := DllCall("GetRawInputData", "UInt", lParam, "UInt", 0x10000003               ; Get RawInput data
                                      , "UPtr", uRawInput.ptr, "UInt*", &sz, "UInt", 8 + (A_PtrSize * 2))
        
        off := A_PtrSize * 2
        xD := 0, yD := 0    ; Ensure we always report a number for an axis. Needed?
        usFlags := NumGet(uRawInput, off, "UShort")
        
        usButtonFlags := NumGet(uRawInput, off + 12, "UShort")
        usButtonData := NumGet(uRawInput, off + 14, "Short")
        
        (usButtonFlags & 0x1) ? b1 := true : ""         ; LB down
        (usButtonFlags & 0x2) ? b1 := false : ""        ; LB up
        
        (usButtonFlags & 0x4) ? b2 := true : ""         ; RB down
        (usButtonFlags & 0x8) ? b2 := false : ""        ; RB up
        
        (usButtonFlags & 0x10) ? b3 := true : ""        ; MB down
        (usButtonFlags & 0x20) ? b3 := false : ""       ; MB up
        
        (usButtonFlags & 0x40) ? b4 := true : ""        ; B4 down
        (usButtonFlags & 0x80) ? b4 := false : ""       ; B4 up
        
        (usButtonFlags & 0x100) ? b5 := true : ""       ; B5 down
        (usButtonFlags & 0x200) ? b5 := false : ""      ; B5 up
        
        (usButtonFlags & 0x400) ? (mw := usButtonData) : (mw := 0) ; mouse wheel delta
        
        xD := NumGet(uRawInput, offsets.x, "Int") ; x Delta
        yD := NumGet(uRawInput, offsets.y, "Int") ; y Delta
        
        POINT := Buffer(8,0)
        DllCall("GetCursorPos","UPtr",POINT.ptr)
        x := NumGet(POINT,"UInt")
        y := NumGet(POINT,4,"UInt")
        
        obj := {x:x, y:y, xD:xD, yD:yD
              , b1:b1, b2:b2, b3:b3, b4:b4, b5:b5, mw:mw}

        callback := this.Callback
        %callback%(ThisMouse, obj)
    }
}


