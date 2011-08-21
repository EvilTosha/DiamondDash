#Include <Constants.au3>					;подключение всего необходимого
#Include <WinAPIEx.au3>
#Include <WindowsConstants.au3>
#Include <ScreenCapture.au3>
#Include <ImageSearch.au3>


HotKeySet("{F2}", "_Start")       ;биндинг клавиш старта, паузы и завершения скрипта
HotKeySet("{F3}", "_Pause")
HotKeySet("{F4}", "_Terminate")


Global $iCornerX									;координаты левого верхнего угла игрового поля
Global $iCornerY									;будут проинициализированны при старте
Global $iNumRows = 9							;размеры игрового поля
Global $iNumCols = 10
Global $iDeltaX = 10							;координаты пикселя внутри одного квадратика
Global $iDeltaY = 4								;по цвету котоорого будет восстанавливаться цвет квадратика
Global $iMouseSpeed = 1						;скорость мыши, 1 - максимум, 10 - стандартно
Global $iStepSleep = 100						;задержка между кликами в миллисекундах


Global $aiDiams[$iNumRows][$iNumCols]					;массив по которому будут определяться алмазы
Global $afJustClicked[$iNumRows][$iNumCols]   ;хранит область последнего клика, чтобы уменьшить количество ошибок
Global $fActive = False												;флаг активности скрипта


Func _Start()
	For $iRow = 0 to $iNumRows - 1
		For $iCol = 0 to $iNumCols - 1
			$aiDiams[$iRow][$iCol] = 0
		Next
	Next
	If (_GetCornerCoords($iCornerX, $iCornerY)) Then  ;получение координат угла поля
		$fActive = True
	EndIf
EndFunc

Func _Pause()
	$fActive = False
EndFunc

Func _Terminate()									;функция завершения скрипта
	Exit 0
EndFunc   ;==>Terminate


Func _GetCornerCoords(ByRef $iX, ByRef $iY)                                ;получение координат угла поля
	$fResult = _ImageSearch("template.bmp", 0, $iX, $iY, 0x15)
	If $fResult = 1 Then
		$iX += 20
		$iY += 20
	Else
		MsgBox(0,"Not Found", "Corner template wasn't found")
		Return False
	EndIf
	Return True
EndFunc

Func Div($iValue1, $iValue2)				;не знаю почему нету стандартной функции неполного частного,
																	;пришлось реализовывать самому =)
	Return ($iValue1 - Mod($iValue1, $iValue2)) / $iValue2
EndFunc

Func _GetCheckColor($iPixelColor)											;получение цвета квадратика по цвету пикселя в нем
	Local $Red = Div($iPixelColor, 0x10000)
	Local $Green =  Mod(Div($iPixelColor, 0x100), 0x100)
	Local $Blue = Mod($iPixelColor, 0x100)
	Local $d = 0x10									;константа погрешности
	;магические числа были подобраны руками. Почти =)
	Select
		Case $Red > 0x90 - $d And $Green < 0x70 + $d And $Blue < 0x70 + $d
			Return 1									;красный
		Case $Red < 0x50 + $d And $Green > 0x90 - $d And $Blue < 0x50 + $d
			Return 2									;зеленый
		Case $Red < 0x50 + $d And $Green < 0x70 + $d And $Blue > 0x90 - $d
			Return 3									;синий
		Case $Red > 0xA0 - $d And $Green > 0xA0 - $d And $Blue < 0x30 + $d
			Return 4									;желтый
		Case $Red > 0x70 - $d And $Green < 0x70 + $d And $Blue > 0x90 - $d
			Return 5									;фиолетовый
		Case Else
			Return 0									;неопределенный цвет
	EndSelect
EndFunc

Func _IsWhite($iPixelColor)												;проверка пикселя на белый цвет
																									;используется для выявления области недавнего взрыва
	Local $Red = Div($iPixelColor, 0x10000)
	Local $Green =  Mod(Div($iPixelColor, 0x100), 0x100)
	Local $Blue = Mod($iPixelColor, 0x100)
	Return ($Red > 0xFA And $Green > 0xFA And $Blue > 0xFA)
EndFunc

Func _GetField(ByRef $aiField)									;получение массива цветов поля
	;получение BitMap-снимка экрана с помощью WinAPI
	Local $hWnd = WinGetHandle("Игры Google+ - Google Chrome")
	Local $Size = WinGetClientSize($hWnd)
	Local $hDC = _WinAPI_GetDC($hWnd)
	Local $hMemDC = _WinAPI_CreateCompatibleDC($hDC)
	Local $hBitmap = _WinAPI_CreateCompatibleBitmap($hDC, $Size[0], $Size[1])
	Local $hSv = _WinAPI_SelectObject($hMemDC, $hBitmap)
	_WinAPI_BitBlt($hMemDC, 0, 0, $Size[0], $Size[1], $hDC, 0, 0, $SRCCOPY)
	_WinAPI_SelectObject($hMemDC, $hSv)
	_WinAPI_DeleteDC($hMemDC)
	_WinAPI_ReleaseDC($hWnd, $hDC)
	Local $L = $Size[0] * $Size[1]
	Local $tBits = DllStructCreate('dword[' & $L & ']')
	_WinAPI_GetBitmapBits($hBitmap, 4 * $L, DllStructGetPtr($tBits))

	For $iCol = 0 To $iNumCols - 1
		Local $fOverExplosion = False							;флаг взрыва в данной колонке
		For $iRow = $iNumRows - 1 to 0 Step -1
			;проверка на взрыв
			Local $iX = 25 + ($iCol * 40) + $iCornerX
			Local $iY = 25 + ($iRow * 40) + $iCornerY
			Local $iPixelColor = Mod(DllStructGetData($tBits, 1, $iY * $Size[0] + $iX), 0x1000000)
			If _IsWhite($iPixelColor) Then
				$fOverExplosion = True
			EndIf
			If $fOverExplosion Then
				$aiField[$iRow][$iCol] = 0
			Else
				;замер цвета квадратика
				$iX = $iCornerX + ($iCol * 40) + $iDeltaX
				$iY = $iCornerY + ($iRow * 40) + $iDeltaY
				$iPixelColor = Mod(DllStructGetData($tBits, 1, $iY * $Size[0] + $iX), 0x1000000)
				$aiField[$iRow][$iCol] = _GetCheckColor($iPixelColor)
			EndIf
		Next
	Next

	;удаление данных для избежаня утечки памяти
	_WinAPI_DeleteObject($hBitmap)
	_WinAPI_DeleteObject($hMemDC)
	_WinAPI_DeleteObject($tBits)

EndFunc


Func _DoClick(ByRef $aiField)											;по информации о поле сделать(или не сделать) клик
	;проверка на алмазы. Если клетка в 3 нижних рядах не определяет цвет 15 ходов, считаем ее алмазом и кликаем на нее
	For $iRow = $iNumRows - 1 to $iNumRows - 3 Step -1
		For $iCol = 0 to $iNumCols - 1
			If $aiField[$iRow][$iCol] <> 0 Then
				$aiDiams[$iRow][$iCol] = 0
			Else
				$aiDiams[$iRow][$iCol] += 1
				If $aiDiams[$iRow][$iCol] > 15 Then
					MouseClick("Left", $iCornerX + 30 + ($iCol * 40), $iCornerY + 10 + ($iRow * 40), 1, $iMouseSpeed)
					$aiDiams[$iRow][$iCol] = 0
					Sleep(500)
					Return 0
				EndIf
			EndIf
		Next
	Next
	;поиск области одноцветных клеток
	For $iRow = $iNumRows - 1 to 0 Step -1
		For $iCol = $iNumCols - 1 to 0 Step -1
			If (Not($afJustClicked[$iRow][$iCol]) And $aiField[$iRow][$iCol] <> 0 And _DfsAreaSize($aiField, $iRow, $iCol) > 2) Then
				MouseClick("Left", $iCornerX + 30 + ($iCol * 40), $iCornerY + 10 + ($iRow * 40), 1, $iMouseSpeed)
				Return 0
			EndIf
		Next
	Next
	For $i = $iNumRows - 1 to 0 Step -1
		For $j = $iNumCols - 1 to 0 Step -1
			$afJustClicked[$i][$j] = False
		Next
	Next
EndFunc


Func _DfsAreaSize(ByRef $aiField, $iStartX, $iStartY)			;нерекурсивный алгоритм поиска размера одноцветной области
																													;методом поиска в глубину
	Local $aiResult[$iNumCols * $iNumRows][2]								;список клеток входящих в область
	Local $iResultSize = 0
	Local $afMap[$iNumRows][$iNumCols]											;флаги пройденности
	For $iRow = 0 to $iNumRows - 1
		For $iCol = 0 to $iNumCols - 1
			$afMap[$iRow][$iCol] = False
		Next
	Next
	$afMap[$iStartX][$iStartY] = True
	Local $aiStack[$iNumRows * $iNumCols][2]								;активный стек
	Local $iStackSize = 1
	$aiStack[0][0] = $iStartX
	$aiStack[0][1] = $iStartY
	While $iStackSize > 0
		$iStackSize -= 1
		$iX = $aiStack[$iStackSize][0]
		$iY = $aiStack[$iStackSize][1]
		$aiResult[$iResultSize][0] = $iX
		$aiResult[$iResultSize][1] = $iY
		$iResultSize += 1
		For $iDirection = 0 to 3															;перебор 4 рядомстоящих клеток
			Local $iNewX = $iX
			Local $iNewY = $iY
			Switch $iDirection
				Case 0
					$iNewY += 1
				Case 1
					$iNewY -= 1
				Case 2
					$iNewX += 1
				Case 3
					$iNewX -= 1
			EndSwitch
			If ($iNewX >= 0 And $iNewX < $iNumRows And _
					$iNewY >= 0 And $iNewY < $iNumCols And _
					Not($afMap[$iNewX][$iNewY]) And $aiField[$iNewX][$iNewY] = $aiField[$iStartX][$iStartY]) Then
				$afMap[$iNewX][$iNewY] = True
				$aiStack[$iStackSize][0] = $iNewX
				$aiStack[$iStackSize][1] = $iNewY
				$iStackSize += 1
			EndIf
		Next
	WEnd
	If $iResultSize > 2 Then
		For $i = $iNumRows - 1 to 0 Step -1
			For $j = $iNumCols - 1 to 0 Step -1
				$afJustClicked[$i][$j] = False
			Next
		Next
		For $i = 0 to $iResultSize - 1
			$afJustClicked[$aiResult[$i][0]][$aiResult[$i][1]] = True
		Next
	EndIf
	Return $iResultSize
EndFunc


While 1                 	;основной цикл
	If $fActive Then
		Sleep($iStepSleep)		;задержка, чтобы не кликало слишком быстро и не ошибалось
		Local $aiField[$iNumRows][$iNumCols]
		_GetField($aiField)
		_DoClick($aiField)
	Else
		Sleep(100)						;работа вхолостую, в ожидании начала
	EndIf
WEnd


