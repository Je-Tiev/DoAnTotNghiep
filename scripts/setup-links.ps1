<#
.SYNOPSIS
  Tao (hoac tai tao) hard links va junction giua git submodule va IDE workspace.
  Chay mot lan sau khi clone, hoac sau khi CubeIDE code-gen tao file moi.

.PARAMETER Node
  sensor | gateway | android | all (mac dinh: all)

.EXAMPLE
  .\setup-links.ps1
  .\setup-links.ps1 -Node sensor
#>
param(
  [ValidateSet('sensor','gateway','android','all')]
  [string]$Node = 'all'
)

# Root la thu muc cha cua script (../ tu scripts/)
$root = Split-Path $PSScriptRoot -Parent

function Link-File($srcBase, $ideBase, $relPaths) {
  $ok = 0; $fail = 0
  foreach ($rel in $relPaths) {
    $target = Join-Path $srcBase $rel
    $link   = Join-Path $ideBase $rel
    if (-not (Test-Path $target)) { Write-Warning "Bo qua (khong co trong submodule): $rel"; continue }
    try {
      if (Test-Path $link) { Remove-Item $link -Force -ErrorAction Stop }
      New-Item -ItemType HardLink -Path $link -Target $target -ErrorAction Stop | Out-Null
      $ok++
    } catch {
      Write-Warning "FAIL: $rel -- $_"
      $fail++
    }
  }
  Write-Host "  $ok hard links OK, $fail loi"
}

function Junction-Dir($srcDir, $ideDir) {
  $item = Get-Item $ideDir -Force -ErrorAction SilentlyContinue
  if ($item -and $item.LinkType -eq 'Junction') {
    Write-Host "  Junction da ton tai: $ideDir"
    return
  }
  if (Test-Path $ideDir) { Remove-Item $ideDir -Recurse -Force }
  cmd /c "mklink /J `"$ideDir`" `"$srcDir`"" | Out-Null
  Write-Host "  Junction OK: $ideDir"
}

$sensorFiles = @(
  'Core\Src\adc.c','Core\Src\can_encode.c','Core\Src\can.c','Core\Src\debug_uart.c',
  'Core\Src\dma.c','Core\Src\freertos.c','Core\Src\gpio.c','Core\Src\hc595.c',
  'Core\Src\keypad.c','Core\Src\light_manager.c','Core\Src\main.c','Core\Src\spi.c',
  'Core\Src\stm32f1xx_hal_msp.c','Core\Src\stm32f1xx_hal_timebase_tim.c',
  'Core\Src\stm32f1xx_it.c','Core\Src\syscalls.c','Core\Src\sysmem.c',
  'Core\Src\system_stm32f1xx.c','Core\Src\usart.c',
  'Core\Inc\adc.h','Core\Inc\can_encode.h','Core\Inc\can_msg.h','Core\Inc\can.h',
  'Core\Inc\debug_uart.h','Core\Inc\dma.h','Core\Inc\FreeRTOSConfig.h','Core\Inc\gpio.h',
  'Core\Inc\hc595.h','Core\Inc\keypad.h','Core\Inc\light_manager.h','Core\Inc\main.h',
  'Core\Inc\spi.h','Core\Inc\stm32f1xx_hal_conf.h','Core\Inc\stm32f1xx_it.h','Core\Inc\usart.h'
)

$gatewayFiles = @(
  'Core\Src\adc.c','Core\Src\can_decode.c','Core\Src\can.c','Core\Src\debug_uart.c',
  'Core\Src\freertos.c','Core\Src\gpio.c','Core\Src\main.c','Core\Src\spi.c',
  'Core\Src\stm32f1xx_hal_msp.c','Core\Src\stm32f1xx_hal_timebase_tim.c',
  'Core\Src\stm32f1xx_it.c','Core\Src\syscalls.c','Core\Src\sysmem.c',
  'Core\Src\system_stm32f1xx.c','Core\Src\usart.c','Core\Src\w5500_port.c',
  'Core\Inc\adc.h','Core\Inc\can_decode.h','Core\Inc\can_msg.h','Core\Inc\can.h',
  'Core\Inc\debug_uart.h','Core\Inc\FreeRTOSConfig.h','Core\Inc\gpio.h','Core\Inc\main.h',
  'Core\Inc\spi.h','Core\Inc\stm32f1xx_hal_conf.h','Core\Inc\stm32f1xx_it.h',
  'Core\Inc\usart.h','Core\Inc\w5500_config.h','Core\Inc\w5500_port.h'
)

if ($Node -in 'sensor','all') {
  Write-Host "Sensor ECU hard links:"
  Link-File (Join-Path $root 'STM32-1st') `
            'C:\Users\coc14\STM32CubeIDE\workspace_2.1.1\STM32_Sensor_CAN' `
            $sensorFiles
}

if ($Node -in 'gateway','all') {
  Write-Host "Gateway ECU hard links:"
  Link-File (Join-Path $root 'STM32-2nd') `
            'C:\Users\coc14\STM32CubeIDE\workspace_2.1.1\STM32_Gateway_CAN' `
            $gatewayFiles
}

if ($Node -in 'android','all') {
  Write-Host "Android junction:"
  Junction-Dir (Join-Path $root 'ClusterApp\app\src\main') `
               'C:\Users\coc14\AndroidStudioProjects\CarClusterApp\app\src\main'
}

Write-Host "`nXong. CubeIDE va Android Studio dung chung file vat ly voi git submodule."
