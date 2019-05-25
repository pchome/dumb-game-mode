#!/bin/sh
#--------------------------------------------------------------------------------
# Modified variant of https://github.com/Lurkki14/gamedetector
#--------------------------------------------------------------------------------

# Status
game_start=0
game_stop=1

# CPU governors
default_governor='conservative'
performance_governor='performance'

# Wait
wait_game_start=5    # seconds
expire_info=2000     # milliseconds
expire_warning=10000 # milliseconds

# specify programs here (separate by a space)
# programs='hl2_linux RocketLeague payday2_release'
programs='wineserver'

#--------------------------------------------------------------------------------
# detector loop
#--------------------------------------------------------------------------------
wait_for() {
  while true; do
    sleep 2
    pidof $programs > /dev/null
    status=$?
    if [ "$status" = $1 ]; then
      break
    fi
  done
}


#--------------------------------------------------------------------------------
# commands to execute when a specified program is started
#--------------------------------------------------------------------------------
start_commands() {
  start_gpu_perf
  start_cpu_perf
  start_notifier

  sleep $wait_game_start;
  start_vkcheck
  start_dxcheck
}


#--------------------------------------------------------------------------------
# commands to execute when a specified program is exited
#--------------------------------------------------------------------------------
stop_commands() {
  stop_gpu_perf
  stop_cpu_perf
}


#--------------------------------------------------------------------------------
# GPU perf mode on
#--------------------------------------------------------------------------------
start_gpu_perf() {
  # 1 - Performance mode
  [ $(which nvidia-settings) ] \
    && nvidia-settings -a GPUPowerMizerMode=1

  # Lock max freq
  # check `nvidia-settings -q GPUPerfModes` (e.g. nvclockmin=135, nvclockmax=1359)
  #
  #[ $(which nvidia-smi) ] && sudo nvidia-smi -ac 2750,1359
}


#--------------------------------------------------------------------------------
# GPU perf mode off
#--------------------------------------------------------------------------------
stop_gpu_perf() {
  # 2 - Adaptive mode
  [ $(which nvidia-settings) ] \
    && nvidia-settings -a GPUPowerMizerMode=2

  # Reset to default greq
  #[ $(which nvidia-smi) ] && sudo nvidia-smi -rac
}


#--------------------------------------------------------------------------------
# CPU perf mode on
#--------------------------------------------------------------------------------
start_cpu_perf() {
  # Performance governor
  [ $(which cpupower) ] \
    && sudo cpupower -c all frequency-set -g $performance_governor
}


#--------------------------------------------------------------------------------
# CPU perf mode off
#--------------------------------------------------------------------------------
stop_cpu_perf() {
  # Conservative governor
  [ $(which cpupower) ] \
    && sudo cpupower -c all frequency-set -g $default_governor
}


#--------------------------------------------------------------------------------
# Notify perf mode is on
#--------------------------------------------------------------------------------
start_notifier() {
  title="Game Mode is ON"
  body="${programs/ /\\n}"

  # Send notification
  [ $(which notify-send) ] \
    && notify-send -u low -t $expire_info -i applications-games "$title" "$body"
}



#--------------------------------------------------------------------------------
# Notify mixed graphic APIs for DXVK/D9VK/NvAPI/OpenGL/...
#--------------------------------------------------------------------------------
start_vkcheck() {
  # lsof: find opened *.dll/*.dll.so
  # awk: check each *.exe for mixed Vk/GL dlls
  # NOTE: will only report if winevulkan.dll found (e.g. for DXVK/D9VK)
  report=$(lsof -nPT -u ${USER} +c 15  | grep -E '\.dll(\.so)?' \
    | awk '
    function reset()      { for (key in apis) SYMTAB[key] = 0; }
    function sum_not_vk() { return ogl + nvapi + ddraw + wined3d; }
    function one_not_vk() { return sum_not_vk() >= 1 ? 1 : 0; }
    function is_mixed()   { return vk ? dxvk + d9vk + one_not_vk() : 0; }
    function report() {
      if(is_mixed() > 1) {
        out = "Mixed API for <b>" cur_exe "</b>:\n";
        for (key in apis)
          if (SYMTAB[key]) out = out "" apis[key] "\n";
        print out; mixed=1;
      }
    } BEGIN {
      mixed=0; cur_exe=""; vk=0; dxvk=0; d9vk=0; ogl=0; nvapi=0; ddraw=0; wined3d=0;

      apis["vk"]   = "Vulkan"; libs["vk"][0] = "winevulkan";

      apis["dxvk"] = "DXVK"; apis["ogl"]   = "OpenGL";  apis["wined3d"] = "WineD3D";
      apis["d9vk"] = "D9VK"; apis["nvapi"] = "NvAPI";   apis["ddraw"] =   "DirectDraw";

      libs["d9vk"][0] = "d3d9.dll";
      libs["dxvk"][0] = "d3d11.dll"; libs["dxvk"][1] = "dxgi";
      libs["dxvk"][2] = "d3d10_1";   libs["dxvk"][3] = "d3d10.dll"; libs["dxvk"][4]    = "d3d10core.dll";
      libs["ogl"][0]  = "opengl32";  libs["ddraw"][0]= "ddraw";     libs["wined3d"][0] = "wined3d";
      libs["nvapi"][0]= "nvapi";     libs["nvapi"][1]= "nvcu";      libs["nvapi"][2]   = "cuda";
    } {
      if (cur_exe == "") cur_exe = $1
      if (cur_exe != $1) { report(); reset(); cur_exe = $1; }

      for (key in apis)
        for (lkey in libs[key])
          if (index($9, libs[key][lkey])) SYMTAB[key] = 1
    } END { report() }')

    #' #for mcedit


  [ z"$report" != z"" ] \
    && [ $(which notify-send) ] \
    && notify-send -u low -t $expire_warning -i applications-games "Wine Vulkan Warning!" "$report"
}


#--------------------------------------------------------------------------------
# Notify native Wine D3DX/D3DCompiler
#--------------------------------------------------------------------------------
start_dxcheck() {
  # lsof: find opened *.dll/*.dll.so
  # awk: check each *.exe for native d3dx/d3dcompiler dlls
  report=$(lsof -nPT -u ${USER} +c 15  | grep -E '\.dll\.so' \
    | awk '
    function reset()  { d3dx = 0; d3dc = 0; list_d3dx = ""; list_d3dc = ""; }
    function found()  { return d3dx + d3dc; }
    function report() {
      if(found()) {
        out = "Wine native libs for <b>" cur_exe "</b>:\n";
        if (d3dc) out = out "" list_d3dc "\n";
        if (d3dx) out = out "" list_d3dx "\n";
        print out; native=1;
      }
    } BEGIN {
      native=0; cur_exe=""; d3dx=0; d3dc=0; list_d3dx = ""; list_d3dc = "";
    } {
      if (cur_exe == "") cur_exe = $1
      if (cur_exe != $1) { report(); reset(); cur_exe = $1; }

      if (index($9, "d3dx1") || index($9, "d3dx9")) {
        d3dx = 1;
        list_d3dx = list_d3dx "\n" gensub(/.*[\/]/, "", 1, $9);
      }
      if (index($9, "d3dcompiler")) {
        d3dc = 1;
        list_d3dc = list_d3dc "\n" gensub(/.*[\/]/, "", 1, $9);
      }
    } END { report() }')


  [ z"$report" != z"" ] \
    && [ $(which notify-send) ] \
    && notify-send -u low -t $expire_warning -i applications-games "Wine D3DX/D3DCompiler Warning!" "$report"
}

#--------------------------------------------------------------------------------
# main loop
#--------------------------------------------------------------------------------
while true; do
  wait_for $game_start
  start_commands
  wait_for $game_stop
  stop_commands
done
