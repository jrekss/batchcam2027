macroScript BatchCameraRender
  category:"Kasymov Islombek"
  toolTip:""
  buttonText:"BatchCam"

-- Batch Camera Render, maxscript tool for batch rendering in 3ds max
-- Copyright (C) 2009-2025, Sergo Pogosyan
-- Modified 2025, Kasymov Islombek
-- 
-- This program is free software; you can redistribute it and/or
-- modify it under the terms of the GNU General Public License
-- as published by the Free Software Foundation; either version 2
-- of the License, or (at your option) any later version.
-- 
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
-- 
-- You should have received a copy of the GNU General Public License
-- along with this program; if not, write to the Free Software
-- Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.


------------------------------------------------------------------------------
-- BatchCameraRender.ms
-- By Sergo Pogosyan (www.sergepogosyan.com, contact@sergepogosyan.com)
-- Modified by Kasymov Islombek
-- Created On: 2009-05-25
-- tested using Max 2009-2025
-------------------------------------------------------------------------------
-- Description:
-- macroscript aims to replace builtin batch render
-------------------------------------------------------------------------------

(
--########################--
--GLOBAL VARS--
--########################--
--render size presets
RESOLUTIONS = #([640,480],[768,576],[900,600],[1200,800],[1200,960],[1500,1000],[1920,1080],[2400,1200],[2400,1920])
--main rollout
local isDialogOpen = false    --variable to save main window open/close state
global batchCameraRender_mainRollOut
Output_Size_Rollout
Render_Output_Rollout
Frame_Range_Rollout
global batchCameraRender_floater
global batchCameraRender_reload_cameras
global batchCameraRender_reset_render_counter
global batchCameraRender_getUserProperty
global batchCameraRender_currentcamera
batchCamPreview = false --always false (preview removed)
global_listview_height = 170
--listView items array
LV_ITEMS = #()
--script version
VERSION_STRING = "2.1"

BatchCam_CommonPropertiesNames = #("frames", "framerange_from", "framerange_to", "anim_frame_range", "frame_width", "frame_heigth", "render_output", \
                          "elements_state", "not_save_elements", "elements_output", "render_preset", "image_aspect" )
--########################--
--Session-wide persistent variables
--########################--
global BatchCamRenderParamsBuffer
global BatchCam_rollout_state
BatchCam_rollout_state = #(true, true, true, true, false)

global BatchCam_rollout_names
BatchCam_rollout_names = #("batchCameraRender_mainRollOut", \
                           "Output_Size_Rollout", "Frame_Range_Rollout", "Render_Output_Rollout", \
                           "aboutRoll")
global BatchCam_listItem_state
--########################--
--end of session-wide persistent variables
--########################--

include @"BatchCameraRender-functions-misc.ms"
include @"BatchCameraRender-functions-populating.ms"
include @"BatchCameraRender-functions-setters.ms"
include @"BatchCameraRender-functions-preparing.ms"
--########################--
--ROLLOUT--
--########################--

  rollout batchCameraRender_mainRollOut "Camera Manager Settings"
  (
    button add_button "Add" align:#left width:65 across:5
    button remove_button "Remove" align:#left offset:[-24,0] width:65
    button copy_button "Copy" align:#right offset:[48,0] width:65
    button paste_button "Paste" align:#right offset:[24,0] width:65
    button refresh "Refresh" align:#right width:65

    dotNetControl lv_objects "ListView" height:global_listview_height --height:170

    button toggle_select_all "[Un]Select All" align:#left width:70 across:6
    button toggle_check_all "[Un]Check All" align:#left width:70 offset: [-2,0]
    button check_selected "Check Selected" align:#left width:80 offset: [-4,0]
    button set_viewport "Set Viewport" align:#right width:70 offset: [6,0] tooltip:"Sets selected viewport to the camera selected in the list"
    button get_viewport "Get Viewport" align:#right width:70 offset: [2,0] tooltip:"Selects viewport's camera in the list"
    button get_selection "Get Selection" align:#right width:75 offset: [4,0] tooltip:"Selects cameras in the list based on scene selection"

    button render_start "Render" align:#left width:70 offset: [0,0] across:3
    button select_camera "Select Camera" align:#right width:75 offset: [0,0] tooltip:"Selects camera object in the scene"

    --#####--
    --list button event handlers--
    --#####--
    on batchCameraRender_mainRollOut resized height do saveVar2IniFile "Main_RollOut" "dialog_height" height[2]

    on refresh pressed do
    (
      batchCameraRender_reload_cameras lv_objects
      ui_elements_refresh lv_objects
    )

    on remove_button pressed do
    (
      local selectItems = batchCameraRender_mainRollOut.lv_objects.SelectedItems.GetEnumerator()
      while selectItems.MoveNext() do
      (
        if (superclassof (selectItems.Current.tag.value) != camera) then
        (
          local camObj = getCameraFromCA (selectItems.Current.tag.value)
          local custDef = (custAttributes.getDef (selectItems.Current.tag.value) baseObject:true)
          custattributes.delete camObj custDef
        )
      )
      BatchCameraRender_reload_cameras lv_objects
    )

    on add_button pressed do
    (
      local batchcam_custattr = attributes BatchCamAttr version:1
      (
      )

      if (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Count == 1) then
      (
        selected_item = (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Item 0)
        camera_obj = selected_item.tag.value

        if (camera_obj != undefined) and (superclassof camera_obj == camera) then
        (
          custattributes.add camera_obj batchcam_custattr #unique

          BatchCameraRender_reload_cameras lv_objects
        )
      )

    )

    on copy_button pressed do
    (
      BatchCamRenderParamsBuffer = BatchCameraRenderParamsStruct()

      if (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Count == 1) then
      (
        selected_item = (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Item 0)
        camera_obj = selected_item.tag.value

        if camera_obj != undefined then
        (
          propertyNames = getPropNames BatchCamRenderParamsBuffer
          for propertyName in propertyNames do
          (
            prop_value = getUserPropertyFromObject camera_obj (propertyName as string)
            setProperty BatchCamRenderParamsBuffer propertyName prop_value
          )
          ui_elements_refresh lv_objects
        )
      )
    )

    on paste_button pressed do
    (
      if BatchCamRenderParamsBuffer != undefined then
      (
        if (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Count > 0) then
        (
          for i=1 to batchCameraRender_mainRollOut.lv_objects.SelectedItems.Count do
          (
            selected_item = (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Item (i-1))
            propertyNames = getPropNames BatchCamRenderParamsBuffer
            for propertyName in propertyNames do
            (
              prop_value = getProperty BatchCamRenderParamsBuffer propertyName
              setUserProperty selected_item (propertyName as string) prop_value
            )
          )
          BatchCameraRender_reload_cameras lv_objects
        )
      )
    )

    on toggle_select_all pressed do
    (
      local listItems = for i=0 to (lv_objects.Items.Count - 1) collect (lv_objects.Items.Item i)
      local is_some_selected = (lv_objects.SelectedItems.Count > 0)

      if is_some_selected then
        lv_objects.SelectedItems.Clear()
      else
      (
        lv_objects.BeginUpdate()
        for i in listItems do
          i.selected = true
        lv_objects.EndUpdate()
      )

      lv_objects.HideSelection = false
      local selectedItems = for i=0 to (lv_objects.SelectedItems.Count - 1) collect (lv_objects.SelectedItems.Item i)
      populate_ui_elements selectedItems
      ui_elements_refresh lv_objects
    )

    on toggle_check_all pressed do
    (
      local listItems = for i=0 to (lv_objects.Items.Count - 1) collect (lv_objects.Items.Item i)
      is_some_checked = false
      for i in listItems do
      (
        if i.checked then is_some_checked = true
      )

      if is_some_checked then
      (
        for i in listItems do
          i.checked = false
      )
      else
      (
        for i in listItems do
          i.checked = true
      )
      ui_elements_refresh lv_objects
    )

    on check_selected pressed do
    (
      for i in LV_ITEMS do
      (
        if i.selected then
          i.checked = true
        else
          i.checked = false
      )
      ui_elements_refresh lv_objects
    )

    on select_camera pressed do
    (
      camera_selection_names = for obj in LV_ITEMS where obj.selected collect obj.text    --get camera names from selected items in list
      camera_selection = for obj in get_camera_list() where ((findItem camera_selection_names obj.name) != 0) collect obj --collect camera objects with names is in previous array

      select camera_selection
    )

    --function to set selected camera to active viewport
    on set_viewport pressed do
    (
      local tag_object = undefined
      for item in LV_ITEMS while tag_object == undefined do
      (
        if item.selected then
        (
          tag_object = item.tag.value
        )
      )

      if (tag_object != undefined) then
      (
        local cam_obj = undefined
        if (superclassof tag_object == camera) then
          cam_obj = tag_object
        else
          cam_obj = getCameraFromCA tag_object

        viewport.setCamera cam_obj

        local xres_prop = getUserProperty tag_object "BatchCameraRender_frame_width"
        local yres_prop = getUserProperty tag_object "BatchCameraRender_frame_heigth"
        if (isNotUndefined xres_prop) and (isNotUndefined yres_prop) then
        (
          if renderSceneDialog.isOpen() then
              renderSceneDialog.close()

          renderWidth = xres_prop as integer
          renderHeight = yres_prop as integer
        )
      )
    )

    on get_selection pressed do
    (
      local camobjs = for obj in selection where superclassof obj == camera collect obj
      local selectedItems = #()
      for obj in camobjs do
      (
        local listItems = lv_objects.Items.GetEnumerator()
        while listItems.MoveNext() do
        (
          local camObj = undefined
          local itemObj = listItems.Current.tag.value
          if (superclassof itemObj == camera) then
              camObj = itemObj
            else
              camObj = getCameraFromCA itemObj

          if (camObj.name == obj.name) then
          (
            append selectedItems (listItems.Current)
          )
        )
      )
      if selectedItems.count > 0 then
      (
        lv_objects.SelectedItems.Clear()
        lv_objects.BeginUpdate()
        for item in selectedItems do
          item.selected = true
        lv_objects.EndUpdate()
        lv_objects.HideSelection = false
      )

      populate_ui_elements selectedItems
        ui_elements_refresh lv_objects
    )

    on get_viewport pressed do
    (
      if viewport.getType() == #view_camera then
      (
        local camera_obj = viewport.getCamera()
        local camera_name = camera_obj.name

        local listItem = undefined
        local listItems = lv_objects.Items.GetEnumerator()
        while listItems.MoveNext() do
        (
          if (listItems.Current.tag.value.name == camera_name) then
          (
            listItem = listItems.Current
            listItem.selected = true
            listItem.EnsureVisible()
          )
          else
          (
            listItems.Current.selected = false
          )
        )

        if (listItem != undfined) then
          populate_ui_elements #(listItem)

        ui_elements_refresh lv_objects
      )
    )

    fn do_render allCameras=
    (
      local temp_string
      local temp_string1
      local temp_string2
      local temp_string3
      local temp_string5

      -- store render params
      renderParamBuf = BatchCam_RenderParameterStore()
      renderParamBuf = storeRenderParams renderParamBuf

      rendUseActiveView = true

      -- render preset saving
      INIFileDir = ((getdir #plugcfg) + "\\BatchCameraRender\\")
      if (getDirectories INIFileDir).count == 0 then makeDir INIFileDir
      tempRP_file = INIFileDir + "temp_render_preset.rps"
      renderpresets.SaveAll 0 tempRP_file

      renderPresetsApplied = false

      local firstCamera = true
      for item in LV_ITEMS do
      (
        if allCameras or item.checked then
        (
          if not firstCamera then
            sleep 2
          firstCamera = false

          -- get camera object
          local camera_to_render = item.tag.value
          local cam_obj = undefined
          if (superclassof camera_to_render == camera) then
            cam_obj = camera_to_render
          else
            cam_obj = getCameraFromCA camera_to_render

          -- unhide camera if hidden
          if (cam_obj.isHiddenInVpt) then
          (
            cam_obj.isHidden = false
            hideByCategory.cameras = false
          )

          -- apply render preset
          temp_string = getUserProperty camera_to_render "BatchCameraRender_render_preset"
          if isNotUndefined temp_string then
          (
            setSilentMode true
            presetsArray = #()
            if (maxVersion())[1] >= 11000 then
              presetsArray = renderPresetMRUList
            presetsNames = for preset in presetsArray collect preset[1]
            presetIndex = finditem presetsNames temp_string
            if presetIndex != 0 then
            (
              presetFile = presetsArray[presetIndex][2]
              renderpresets.LoadAll 0 presetFile
              renderPresetsApplied = true
            )
            setSilentMode false
          )

          -- set frame range
          temp_string1 = getUserProperty camera_to_render "BatchCameraRender_frames"
          temp_string2 = getUserProperty camera_to_render "BatchCameraRender_framerange_from"
          temp_string3 = getUserProperty camera_to_render "BatchCameraRender_framerange_to"
          temp_string5 = getUserProperty camera_to_render "BatchCameraRender_anim_frame_range"

          if isNotUndefined temp_string5 then
          (
            rendTimeType = 3
            temp_frame_range = get_key_range cam_obj
            rendStart = temp_frame_range[1].frame
            rendEnd = temp_frame_range[2].frame
          )
          else if isNotUndefined temp_string1 then
          (
            rendTimeType = 4
            rendPickupFrames = temp_string1 as string
          )
          else if isNotUndefined temp_string2 then
          (
            rendTimeType = 3
            rendStart = temp_string2 as integer
            rendEnd = temp_string3 as integer
          )

          rendNThFrame = Frame_Range_Rollout.render_every_nth.value as integer

          -- set frame resolution
          xres_prop = getUserProperty camera_to_render "BatchCameraRender_frame_width"
          yres_prop = getUserProperty camera_to_render "BatchCameraRender_frame_heigth"
          if (isNotUndefined xres_prop) and (isNotUndefined yres_prop) then
          (
            renderWidth = xres_prop as integer
            renderHeight = yres_prop as integer
          )

          -- set output file
          temp_string = getUserProperty camera_to_render "BatchCameraRender_render_output"
          if (shouldBeSaved()) and (isNotUndefined temp_string) then
          (
            temp_string = parse_file_name_template temp_string (compose_parsing_dictionary camera_to_render)
            temp_path = getFilenamePath temp_string
            if (not (doesFileExist temp_path)) then
            (
              if not makeDir temp_path all:true then
                throw ("Failed to create path: "+ temp_path)
            )
            rendSaveFile = Render_Output_Rollout.save_file.checked
            rendOutputFilename = temp_string
          )
          else
            rendSaveFile = false

          -- prepare render elements
          local elementsPath = prepare_render_elements camera_to_render

          -- save last render path
          setUserProperty item "BatchCameraRender_lastRenderPath" rendOutputFilename

          -- render
          viewport.setCamera cam_obj
          max quick render

          -- restore render preset if applied
          if renderPresetsApplied then
          (
            INIFileDir = ((getdir #plugcfg) + "\\BatchCameraRender\\")
            tempRP_file = INIFileDir + "temp_render_preset.rps"
            if doesFileExist tempRP_file then
              renderpresets.LoadAll 0 tempRP_file
          )
          restoreRenderParams renderParamBuf
        ) -- end if checked
      ) -- end for loop
    )

    --#####--
    --render button event hadler--
    --#####--
    on render_start pressed do
    (
      query_approved = true
      if renderSceneDialog.isOpen() then
        renderSceneDialog.close()

      --check the render type and suggest to switch to view mode
      if (not GetQuietMode()) and query_approved and getRenderType() != #view and getRenderType() != #normal then
      (
        local message_text = "Render Type set to \"" + (getRenderType() as string) + "\".\n\nWould you like to switch to View mode?"
        local message_buttons = (dotnetclass "MessageBoxButtons").YesNoCancel
        local message_icon = (dotnetclass "MessageBoxIcon").Question
        result = (dotnetclass "MessageBox").show message_text "Caution" message_buttons message_icon
        if (result == ((dotnetclass "DialogResult").Yes)) then
          setRenderType #view
        else if (result == ((dotnetclass "DialogResult").No)) then
          query_approved = true
        else
          query_approved = false
      )

      if query_approved then
      (
        renderSceneDialog.close()

        batchCameraRender_reload_cameras batchCameraRender_mainRollOut.lv_objects

        do_render false

      )
      else
      (
        --cancellation
      )
    )

    --############
    --ON OPEN event handler
    --initialization
    --############

    on batchCameraRender_mainRollOut open do
    (
      init_ListView lv_objects (get_camera_list())

      --this array contains listview items for convinience
      LV_ITEMS = for i=0 to (lv_objects.Items.Count - 1) collect (lv_objects.Items.Item i)

      --refresh ui elements
      if (lv_objects.items.count == 0) then --only call refresh if empty listview, because init_ListView/fill_ListView will refresh anyway
        ui_elements_refresh lv_objects

      --add onopen callback
      callbacks.addScript #filePostOpen "batchCameraRender_reload_cameras batchCameraRender_mainRollOut.lv_objects" id:#batchcam
      callbacks.addScript #filePostMerge "batchCameraRender_reload_cameras batchCameraRender_mainRollOut.lv_objects" id:#batchcam
      callbacks.addScript #systemPostNew "batchCameraRender_reload_cameras batchCameraRender_mainRollOut.lv_objects" id:#batchcam
      callbacks.addScript #systemPostNew "batchCameraRender_reset_render_counter()" id:#batchcam
      callbacks.addScript #systemPostReset "batchCameraRender_reload_cameras batchCameraRender_mainRollOut.lv_objects" id:#batchcam
      callbacks.addScript #systemPostReset "batchCameraRender_reset_render_counter()" id:#batchcam
    )

    on batchCameraRender_mainRollOut close do
    (
      --store checked state of the items to array
      for i=1 to lv_objects.Items.count do
      (
        BatchCam_listItem_state[i] = lv_objects.Items.Item[i-1].checked
      )
      --set flag to show that main window is closed
      isDialogOpen = false
      updateToolbarButtons()
      --remove all script callbacks
      callbacks.removeScripts id:#batchcam
    )

    on batchCameraRender_mainRollOut moved pos do
    (
      if (batchCameraRender_mainRollOut.placement != #minimized) and (batchCameraRender_mainRollOut.placement != #maximized) then
      (
        saveVar2IniFile "Main_RollOut" "dialog_height_x" pos[1]
        saveVar2IniFile "Main_RollOut" "dialog_height_y" pos[2]
      )
    )
    --##########--
    --select item event handler - DOTNET VERSION--
    --##########--
    fn ItemsSelected event args=
    (
      selectedItems = #()
      for i=0 to (lv_objects.SelectedItems.Count - 1) do
        append selectedItems (lv_objects.SelectedItems.Item i)

      LV_ITEMS = selectedItems

      local t = timeStamp()
      populate_ui_elements selectedItems
      ui_elements_refresh lv_objects
    )

    on lv_objects ItemSelectionChanged val  do
    (
      selectedItems = #()
      for i=0 to (lv_objects.SelectedItems.Count - 1) do
        append selectedItems (lv_objects.SelectedItems.Item i)

      LV_ITEMS = selectedItems

      populate_ui_elements selectedItems
      ui_elements_refresh lv_objects
    )

    --check event handler
    --used to save items' checked state
    on lv_objects ItemCheck val do
    (
      BatchCam_listItem_state[(val.Index+1)] = (val.NewValue == (dotNetClass "CheckState").Checked )
    )

    on lv_objects ItemChecked val do
    (
      --todo: save checked state to the camera appdata
      if (globalvars.isGlobal #batchCameraRender_loading_items) then
      (
        if not (globalvars.get #batchCameraRender_loading_items) then
        (
          ui_elements_refresh lv_objects
          globalvars.set #batchCameraRender_loading_items false
        )
        else
        (
          globalvars.set #batchCameraRender_loading_items ((lv_objects.items.count-1) != val.item.index) --call refresh when itemcheck
        )
      )
      else
      (
        global batchCameraRender_loading_items = false
      )
    )

    on lv_objects ItemDrag sender args do
    (
      lv_objects.DoDragDrop args.Item (dotnetclass "DragDropEffects").Move
    )

    on lv_objects DragEnter sender args do
    (
      args.Effect = args.AllowedEffect
    )

    on lv_objects DragOver sender args do
    (
      local targetPoint = lv_objects.PointToClient (dotnetobject "system.drawing.Point" args.X args.Y)
      local targetIndex = lv_objects.InsertionMark.NearestIndex targetPoint
      if (targetIndex > -1) then
      (
        local itemBounds = lv_objects.GetItemRect targetIndex
        if ( targetPoint.Y > (itemBounds.Top + (itemBounds.Height / 2)) ) then
          lv_objects.InsertionMark.AppearsAfterItem = true
        else
          lv_objects.InsertionMark.AppearsAfterItem = false
      )
      lv_objects.InsertionMark.Index = targetIndex
    )

    on lv_objects DragLeave sender args do
    (
      lv_objects.InsertionMark.Index = -1
    )

    on lv_objects DragDrop sender args do
    (
      local targetIndex = lv_objects.InsertionMark.Index

      if (targetIndex != -1) then
      (
        if (lv_objects.InsertionMark.AppearsAfterItem) then
          targetIndex += 1

        local draggedItem = args.Data.GetData (dotNet.getType "System.Windows.Forms.ListViewItem")

        local newItem = draggedItem.Clone()
        for i=0 to (newItem.SubItems.Count-1) do ((newItem.SubItems.Item i).Name = (draggedItem.SubItems.Item i).Name)

        lv_objects.Items.Insert targetIndex (newItem)

        lv_objects.Items.Remove draggedItem

        for i = 0 to lv_objects.Items.Count-1 do
        (
          local listItem = lv_objects.Items.Item i
          setUserProperty listItem ("BatchCameraRender_item_index") (listItem.index as string)
        )
        LV_ITEMS = for i=0 to (lv_objects.Items.Count - 1) collect (lv_objects.Items.Item i)
        for i=1 to LV_ITEMS.count do
        (
          BatchCam_listItem_state[i] = LV_ITEMS[i].checked
        )
      )
    )

    on batchCameraRender_mainRollOut rolledUp state do
    (
      -- find rollout index in main windows's rollouts
      index = findItem BatchCam_rollout_names batchCameraRender_mainRollOut.name
      -- set rollout state to the apropriate array element
      BatchCam_rollout_state[index] = state
    )
  )

  rollout Output_Size_Rollout "Output Size"
  (
    dropdownlist out_size_list width:200  across:3
    button clear_resolution "Clear" width:45  offset: [65,0] align:#right
    button save_as_default  "Save to INI..." width:85 align:#right

    label label1 "Width:" align:#left across:4
    spinner frame_width range:[1,100000,640] type:#integer align:#left width:60 offset: [-32,0]

    spinner image_aspect_spinner "Aspect:" range:[0,100000,1.333] type:#float width:90 offset: [-20,0]
    checkbutton lock_aspect "Lock" width:30 align:#left offset: [2,-3]

    label label3 "Height:" align:#left across:6
    spinner frame_height range:[1,100000,480] type:#integer width:60 align:#left offset: [-13,0]
    button double_resolution "x2" width:30 align:#left offset: [5,-2]
    button half_resolution "1/2" width:30 align:#left offset: [-8,-2]
    button set_resolution_to_max "Set" width:30 align:#left offset: [-20,-2]
    button get_resolution_from_max "Get" width:30 align:#left offset: [-33,-2]

    on Output_Size_Rollout open do
    (
      --resolution dropdownlist init
      temparray = #()
      for i in RESOLUTIONS do
      (
        append temparray ("" + (i[1] as integer) as string + " x " + (i[2] as integer) as string)
      )
      out_size_list.items  = temparray

      --save lock aspect checked state
      if (temp_state = loadVarFromIniFile "Output_Size_Rollout" "lock_aspect") != undefined then
        lock_aspect.checked = (temp_state as booleanClass)
      else
      (
        lock_aspect.checked = false
        saveVar2IniFile "Output_Size_Rollout" "lock_aspect" false
      )
    )

    --##########--
    --set render size event handler--
    --##########--

    on save_as_default pressed do
    (
      if (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Count == 1) then
      (
        selected_item = (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Item 0)
        camera_object = selected_item.tag.value

        property_names = #( "BatchCameraRender_frame_width", \
                        "BatchCameraRender_frame_heigth", \
                        "BatchCameraRender_image_aspect" \
                      )

        saveDefaultValues camera_object property_names
      )
    )

    on out_size_list selected item do
    (
      --call method to add/update properties to selected camera object
      set_resolution LV_ITEMS RESOLUTIONS[item][1] RESOLUTIONS[item][2]
      populate_resolution_options LV_ITEMS
    )

    on frame_width changed val do
    (
      val = val as float
      set_resolution_width LV_ITEMS val
      populate_resolution_options LV_ITEMS
    )

    on frame_height changed val do
    (
      val = val as float
      set_resolution_height LV_ITEMS val
      populate_resolution_options LV_ITEMS
    )

    on lock_aspect changed state do
    (
      image_aspect_spinner.enabled = (state != true)
      saveVar2IniFile "Output_Size_Rollout" "lock_aspect" state
      populate_resolution_options LV_ITEMS
    )

    on image_aspect_spinner changed val do
    (
      set_aspect_ratio LV_ITEMS val
      populate_resolution_options LV_ITEMS
    )

    on clear_resolution pressed do
    (
      for i in LV_ITEMS do
      (
        if i.selected then
        (
          setUserProperty i "BatchCameraRender_frame_width" undefined
          setUserProperty i "BatchCameraRender_frame_heigth" undefined
          setUserProperty i "BatchCameraRender_image_aspect" undefined

          clear_sub_item i "resolution"
          clear_sub_item i "image_aspect"
        )
      )
      populate_resolution_options LV_ITEMS
    )

    on double_resolution pressed do
    (
      set_resolution_by_ratio LV_ITEMS 2 2
      populate_resolution_options LV_ITEMS
    )

    on half_resolution pressed do
    (
      set_resolution_by_ratio LV_ITEMS .5 .5
      populate_resolution_options LV_ITEMS
    )

    on set_resolution_to_max pressed do
    (
      if (not frame_width.indeterminate) and (not frame_height.indeterminate) then
      (
        query_approved = true
        if renderSceneDialog.isOpen() then
          query_approved = queryBox "Render Setup Dialog is open. To set resolution to Render Setup Dialog it should be closed.\n\nWould you like to close it now?" title:"Caution"
        if query_approved do
        (
            renderSceneDialog.close()
            renderWidth = frame_width.value
            renderHeight = frame_height.value
        )
      )
    )

    on get_resolution_from_max pressed do
    (
      query_approved = true
      if renderSceneDialog.isOpen() then
        query_approved = queryBox "Render Setup Dialog is open. To properly get resolution from Render Setup Dialog it should be closed.\n\nWould you like to close it now?" title:"Caution"
      if query_approved do
      (
        renderSceneDialog.close()
        set_resolution LV_ITEMS (renderWidth) (renderHeight)
        populate_resolution_options LV_ITEMS
      )
    )

    on Output_Size_Rollout rolledUp state do
    (
      -- find rollout index in main windows's rollouts
      index = findItem BatchCam_rollout_names Output_Size_Rollout.name
      -- set rollout state to the apropriate array element
      BatchCam_rollout_state[index] = state
    )
  )

  rollout Render_Output_Rollout "Render Output"
  (
    group "Main Output"
    (
      checkbox save_file "Save File" tooltip:"Common property for all camera.\nPersistent during current 3dsmax session" align:#left across:3
      button clear_render_output "Clear" width:45 offset: [65,0] align:#right
      button save_as_default  "Save to INI..." width:85 align:#right

      button file_button "File..." align:#left width:60 across:2
      edittext result_file_name width:320 offset: [-167,0] readonly:true align:#left

      label label1 "Filename:" align:#left across:3
      edittext file_name width:320 offset: [-90,0]
      button syntax_info "Syntax" width:65 align:#right enabled:false
      button folder_button "..." align:#left width:40 offset: [0,-2] across:3
      edittext file_path width:320 align:#left offset: [-90,0]
      button open_current_folder "Open Folder" width:65 align:#right

      --last rendered location
      edittext last_render_path "Last Rendered Location: " width:384 readonly:true align:#left across:2
      button open_last_folder "Open Folder" width:65 offset: [0,-2] align:#right
    )
    group "Render Elements Folder/Subfolder"
    (
      checkbox save_elements "Enable Elements" tooltip:"Enable Render Elements" align:#left
      checkbox not_save_elements "Do not save Elements" toolTip:"Rendering, but not save Render Elements" align:#left
      button elements_folder_button "..." align:#left width:40 offset: [0,-2] across:2
      edittext elements_path width:320 align:#left offset: [-168,0]
    )

    on save_as_default pressed do
    (
      if (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Count == 1) then
      (
        selected_item = (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Item 0)
        camera_object = selected_item.tag.value

        property_names = #( \
                        "BatchCameraRender_render_output", \
                        "BatchCameraRender_elements_state", \
                        "BatchCameraRender_not_save_elements", \
                        "BatchCameraRender_elements_output" \
                      )

        saveDefaultValues camera_object property_names
      )
    )

    on Render_Output_Rollout open do
    (
      --get settings from global variables
      --save file state
      if (temp_state = loadVarFromIniFile "Render_Output_Rollout" "save_file")  != undefined then
        save_file.checked = (temp_state as booleanClass)
      else
      (
        save_file.checked = true
        saveVar2IniFile "Render_Output_Rollout" "save_file" true
      )
    )

    --save settings in global vars.
    on save_file changed state do
      saveVar2IniFile "Render_Output_Rollout" "save_file" state

    on syntax_info pressed do
    (
      info_string = "You can use special keywords in file name and folder paths.\nCurrently supported keywords are:\n\n"
      info_string += "%cameraname%\n%renderpreset%\n%resolution%\n%date%\n%scenename%\n%projectfolder% and %projectpath%\n%projectname%\n"
      info_string += "%scenefolder% and %scenepath%\n\n%up%  - to change preceding path one folder upward\n"
      info_string += "%trynum% - counts how many times the render button was pressed\n\n"
      info_string += "%elementtype%\n%elementname%  - both work in element subfolder and element name template\n\n"
      info_string += "%mainoutput%  and %renderfile% - doesn't works in Main Output path and filename\n\n"
      info_string += "%mainpath%  and %renderpath% - doesn't works in Main Output path and filename\n\n"
      info_string += "Example:\nThe string:\nD:\\Work\\%projectname%\\%date%\\%cameraname%.jpg\nwill yield the path:\nD:\\Work\\villa\\2009-10-28\\living room.jpg"
      messagebox info_string title:"File name template info" beep:false
    )

    on file_button pressed do
    (
      try
        image_file_name = getBitmapSaveFileName()
      catch (getCurrentException())

      if image_file_name != undefined then
      (
        set_render_output LV_ITEMS image_file_name
        populate_filename_fields LV_ITEMS
      )
    )

    on file_name entered val do
    (
      set_render_file LV_ITEMS val
      populate_filename_fields LV_ITEMS
    )

    on file_path entered val do
    (
      set_render_folder LV_ITEMS val
      populate_filename_fields LV_ITEMS
    )

    --set the folder via the dialog box
    on folder_button pressed do
    (
      temp_path = getFilenamePath file_path.text

      while (temp_path != "") and (not (doesFileExist temp_path)) do
        temp_path = pathConfig.removePathLeaf temp_path

      folder_name = getSavePath caption:"Choose Folder" initialDir:temp_path
      if folder_name != undefined then
      (
        set_render_folder LV_ITEMS folder_name
        populate_filename_fields LV_ITEMS
      )
    )

    --open explorer window
    on open_current_folder pressed do
    (
      temp_path = getFilenamePath file_path.text

      --if only one camera is selected then parse the file path
      if (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Count == 1) then
      (
        selected_item = (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Item 0)
        parsed_path = parse_file_name_template temp_path (compose_parsing_dictionary (selected_item.tag.value))
        temp_path  = parsed_path
      )

      while (temp_path != "") and (not (doesFileExist temp_path)) do
        temp_path = pathConfig.removePathLeaf temp_path
      if (doesFileExist temp_path) then
      (
        temp_res = ShellLaunch ("explorer.exe") ( "/n, " + temp_path)
      )
      else
        messagebox ("Path does not exist: "+ temp_path) title:"Error"
    )

    on save_elements changed state do
    (
      set_elements_state LV_ITEMS state
    )

    on not_save_elements changed state do
    (
      set_not_save_elements LV_ITEMS state
    )

    on elements_path entered val do
    (
      set_elements_path LV_ITEMS val
      populate_filename_fields LV_ITEMS
    )

    --set the folder via the dialog box
    on elements_folder_button pressed do
    (
      folder_name = getSavePath caption:"Choose Folder" initialDir:file_path.text
      if folder_name != undefined then
      (
        set_elements_path LV_ITEMS folder_name
        populate_filename_fields LV_ITEMS
      )
    )

    on clear_render_output pressed do
    (
      for i in LV_ITEMS do
      (
        if i.selected then
        (
          setUserProperty i "BatchCameraRender_render_output" undefined
          clear_sub_item i "path"
          setUserProperty i "BatchCameraRender_elements_state" undefined
          clear_sub_item i "elements_state"
          setUserProperty i "BatchCameraRender_not_save_elements" undefined
          clear_sub_item i "not_save_elements"
          setUserProperty i "BatchCameraRender_elements_output" undefined
          clear_sub_item i "elements_path"
        )
      )
      populate_filename_fields LV_ITEMS
    )

        --open explorer window
    on open_last_folder pressed do
    (
      temp_path = getFilenamePath last_render_path.text

      while (temp_path != "") and (not (doesFileExist temp_path)) do
        temp_path = pathConfig.removePathLeaf temp_path
      if ((isNotUndefined temp_path) and (doesFileExist temp_path)) then
      (
        temp_res = ShellLaunch ("explorer.exe") ( "/n, " + temp_path)
      )
      else
        messagebox ("Path does not exist: "+ temp_path) title:"Error"
    )

    on Render_Output_Rollout rolledUp state do
    (
      -- find rollout index in main windows's rollouts
      index = findItem BatchCam_rollout_names Render_Output_Rollout.name
      -- set rollout state to the apropriate array element
      BatchCam_rollout_state[index] = state
    )
  )

  rollout Frame_Range_Rollout "Frame Range"
  (
      radiobuttons rendType1 labels:#("Single") columns:1 default:1 align:#left across:5
      spinner render_single range:[-10000,10000,0] type:#integer width:70 align:#left offset: [-26,0] enabled:false
      button set_current "Set Current" offset: [-20,-3] width:65 align:#left    --button to set current frame

      button clear_frames "Clear" width:45 align:#right
      button save_as_default  "Save to INI..." width:85 align:#right

      radiobuttons rendType2 labels:#("Range") columns:1 default:0 align:#left across:6
      spinner render_from  range:[-10000,10000,0] type:#integer width:70 align:#left offset: [-10,0] enabled:false
      label label1 "To" align:#left offset: [-9,0]
      spinner render_to  range:[-10000,10000,10] type:#integer width:70 align:#left offset: [-65,0] enabled:false
      label label2 "Every Nth Frame:(not saving)" align:#right offset: [0,0]
      spinner render_every_nth range:[1,10000,0] type:#integer width:70 align:#right offset: [0,0] enabled:false

      radiobuttons rendType3 labels:#("Frames") columns:1 default:0 align:#left across:2
      edittext render_frames fieldWidth:250 offset: [-167,0] enabled:false

      radiobuttons rendType5 labels:#("Anim. Range") columns:1 default:0 align:#left across:3
      edittext render_anim_from width:70 offset: [-70,0] readonly:true
      edittext render_anim_to width:70 offset: [-150,0] readonly:true

    on save_as_default pressed do
    (
      if (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Count == 1) then
      (
        selected_item = (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Item 0)
        camera_object = selected_item.tag.value

        property_names = #( \
                        "BatchCameraRender_frames", \
                        "BatchCameraRender_framerange_from", \
                        "BatchCameraRender_framerange_to", \
                        "BatchCameraRender_anim_frame_range" \
                      )

        saveDefaultValues camera_object property_names
      )
    )

    on render_every_nth changed val do
      saveVar2IniFile "Frame_Range_Rollout" "render_every_nth" val

    on Frame_Range_Rollout open do
    (
      if (temp_state = loadVarFromIniFile "Frame_Range_Rollout" "render_every_nth") != undefined then
        render_every_nth.value = (temp_state as integer)
      else
      (
        render_every_nth.value = 1
        saveVar2IniFile "Frame_Range_Rollout" "render_every_nth" 1
      )
    )

    on rendType1 changed val do
    (
      if val==1 then
      (
        rendType2.state = 0
        rendType3.state = 0
        rendType5.state = 0
        render_single.enabled = true
        render_anim_to.enabled=render_anim_from.enabled= render_from.enabled = render_to.enabled = render_frames.enabled = false
        set_frame_single LV_ITEMS render_single.value
      )
    )

    on set_current pressed do
    (
      rendType1.state = 1
      rendType2.state = 0
      rendType3.state = 0
      rendType5.state = 0
      render_single.enabled = true
      render_anim_to.enabled=render_anim_from.enabled= render_from.enabled = render_to.enabled = render_frames.enabled = false

      render_single.value = sliderTime.frame
      set_frame_single LV_ITEMS render_single.value
    )

    on rendType2 changed val do
    (
      if val==1 then
      (
        rendType1.state = 0
        rendType3.state = 0
        rendType5.state = 0
        render_from.enabled = render_to.enabled = true
        set_current.enabled = render_single.enabled = render_anim_to.enabled=render_anim_from.enabled= render_frames.enabled = false
        set_frame_range LV_ITEMS render_from.value render_to.value
      )
    )
    on rendType3 changed val do
    (
      if val==1 then
      (
        rendType1.state = 0
        rendType2.state = 0
        rendType5.state = 0
        set_current.enabled = render_anim_to.enabled=render_anim_from.enabled= render_from.enabled = render_to.enabled = false
        render_frames.enabled = true

        if render_frames.text != "" then
          set_frames LV_ITEMS render_frames.text
      )
    )


    on rendType5 changed val do
    (
      if val==1 then
      (
        rendType1.state = 0
        rendType2.state = 0
        rendType3.state = 0
        set_current.enabled = render_single.enabled = render_frames.enabled = render_from.enabled = render_to.enabled = false
        render_anim_to.enabled=render_anim_from.enabled= true
        set_anim_frame_range LV_ITEMS
      )
    )
    on render_from changed val do
    (
      rendType1.state = 0
      rendType2.state = 1
      rendType3.state = 0
      rendType5.state = 0
      set_frame_range LV_ITEMS render_from.value render_to.value
    )
    on render_to changed val do
    (
      rendType1.state = 0
      rendType2.state = 1
      rendType3.state = 0
      rendType5.state = 0
      set_frame_range LV_ITEMS render_from.value render_to.value
    )
    on render_single changed val do
    (
      rendType1.state = 1
      rendType2.state = 0
      rendType3.state = 0
      rendType5.state = 0
      set_frame_single LV_ITEMS render_single.value
    )
    on render_frames changed val do
    (
      rendType1.state = 0
      rendType2.state = 0
      rendType3.state = 1
      rendType5.state = 0

      tempstring = ""
      teststr = #("0","1","2","3","4","5","6","7","8","9","-",","," ")
      for i=1 to val.count do
      (
        tempchar = val[i]
        if finditem teststr tempchar != 0 then
          tempstring = tempstring + tempchar
      )
      render_frames.text  = tempstring
    )
    on render_frames entered val do
    (
      rendType1.state = 0
      rendType2.state = 0
      render_from.enabled = render_to.enabled = false
      set_frames LV_ITEMS val
    )
    on clear_frames pressed do
    (
      for i in LV_ITEMS do
      (
        if i.selected then
        (
          setUserProperty i "BatchCameraRender_framerange_from" undefined
          setUserProperty i "BatchCameraRender_framerange_to" undefined
          clear_sub_item i "Frames"
        )
      )
      populate_framerange LV_ITEMS
    )

    on Frame_Range_Rollout rolledUp state do
    (
      index = findItem BatchCam_rollout_names Frame_Range_Rollout.name
      BatchCam_rollout_state[index] = state
    )
  )

  rollout aboutRoll "About"
  (
    label lb_about ""
    label lb_author "(C) 2009-2025, Sergo Pogosyan | Modified by Kasymov Islombek"
    hyperLink lb_email "" address:"" align:#center visible:false
    hyperLink lb_homepage "" address:"" align:#center visible:false
    edittext license_text "" height:180 align:#center labelOnTop:true readOnly:true text:\
@"This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA."

    on aboutRoll rolledUp state do
    (
      -- find rollout index in main windows's rollouts
      index = findItem BatchCam_rollout_names aboutRoll.name
      -- set rollout state to the apropriate array element
      BatchCam_rollout_state[index] = state
    )

    on aboutRoll open do
      lb_about.text ="Camera Manager " + VERSION_STRING
  )
  --#################################
  --####          macroscript event handlers       #######
  --#################################

  on isChecked do isDialogOpen  --return true if rollout is open

  on execute do
  (
    --here can be placed initialization code
    --to set window placement, size, etc.
    --listview height var
    if (temp_listview_height = loadVarFromIniFile "Main_RollOut" "listview_height") != undefined then
      global_listview_height = (temp_listview_height as integer)

    if isDialogOpen then --if open, close it
    (
      CloseRolloutFloater batchCameraRender_floater
      isDialogOpen = false --and lower the flag
    )
    else --if closed, open it
    (
      temp_height = (loadVarFromIniFile "Main_RollOut" "dialog_height")

      temp_pos_x = (loadVarFromIniFile "Main_RollOut" "dialog_height_x")
      temp_pos_y = (loadVarFromIniFile "Main_RollOut" "dialog_height_y")

      if (temp_pos_x == undefined and temp_pos_y == undefined) then
      (
        temp_pos_x = 200
        temp_pos_y = 200
      )

      batchCameraRender_floater = newRolloutFloater ("Batch Camera Render " + VERSION_STRING) 500 (if temp_height == undefined then 850 else (temp_height as integer)) (temp_pos_x  as integer) (temp_pos_y as integer)

      state = BatchCam_rollout_state[findItem BatchCam_rollout_names "batchCameraRender_mainRollOut"]
      if state != undefined then state else state = false
      addRollout batchCameraRender_mainRollOut batchCameraRender_floater rolledUp:(not state)
      state = BatchCam_rollout_state[findItem BatchCam_rollout_names "Output_Size_Rollout"]
      if state != undefined then state else state = false
      addRollout Output_Size_Rollout batchCameraRender_floater rolledUp:(not state)
      state = BatchCam_rollout_state[findItem BatchCam_rollout_names "Frame_Range_Rollout"]
      if state != undefined then state else state = false
      addRollout Frame_Range_Rollout batchCameraRender_floater rolledUp:(not state)
      state = BatchCam_rollout_state[findItem BatchCam_rollout_names "Render_Output_Rollout"]
      if state != undefined then state else state = false
      addRollout Render_Output_Rollout batchCameraRender_floater rolledUp:(not state)
      state = BatchCam_rollout_state[findItem BatchCam_rollout_names "aboutRoll"]
      if state != undefined then state else state = false
      addRollout aboutRoll batchCameraRender_floater rolledUp:(not state)
      elements_active false
      render_buttons_active false

      BatchCam_rollout_names = for roll in batchCameraRender_floater.rollouts collect roll.name
      --rollout state store and restore function
      for i=1 to batchCameraRender_floater.rollouts.count do
      (
        if BatchCam_rollout_state == undefined then
        (
          BatchCam_rollout_state = #()
          --initial state if no saved state
          aboutRoll.open = False
        )
        if BatchCam_rollout_state[i] != undefined then
        (
        )
        else
        (
          BatchCam_rollout_state[i] = batchCameraRender_floater.rollouts[i].open
        )
      )
      batchCameraRender_mainRollOut.scrollPos = 0
      batchCameraRender_mainRollOut.lv_objects.Refresh() --refresh the dotNet control
      escapeEnable = false
      isDialogOpen = true --and raise the flag
    )
  )

  on closeDialogs do
  (
    CloseRolloutFloater batchCameraRender_floater
  )
)
