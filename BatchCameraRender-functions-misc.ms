--########################--
--FUNCTIONS for batch camera render script
--########################--
--

fn CompileDotNet25 src =
(
  local csharpProvider = dotnetobject "Microsoft.CSharp.CSharpCodeProvider"
  local compilerParams = dotnetobject "System.CodeDom.Compiler.CompilerParameters"
  compilerParams.ReferencedAssemblies.AddRange #("System.dll", "System.Windows.Forms.dll")
  compilerParams.GenerateInMemory = true
  local compilerResults = csharpProvider.CompileAssemblyFromSource compilerParams #(src)
  if (compilerResults.Errors.Count > 0 ) then
  (
    local errs = stringstream ""
    for i = 0 to (compilerResults.Errors.Count-1) do
    (
      err = compilerResults.Errors.Item[i]
      format "Error:% Line:% Column:% %\n" err.ErrorNumber err.Line err.Column err.ErrorText to:errs
    )
    format "Errors encountered while compiling C# code\n" errs
    format "%\n" errs
  )
)

fn CompileDotNet26 src =
(
  local CSharpCompilationHelper = dotnetclass "CSharpUtilities.CSharpCompilationHelper"
  CSharpCompilationHelper.compile src #()
)

fn CompileDotNet src =
(
	if (maxVersion())[1] >= 28000 then
	(
		CompileDotNet26 src
	)
	else
	(
		CompileDotNet25 src
	)
)

fn shouldBeSaved =
(
  local result = false
  result = (not batchCamPreview) and (Render_Output_Rollout.save_file.checked)
  result
)

--function adds subitem to list item and makes it style active or inactive
fn  add_sub_item listItem subitem_value subitem_name active_state =
(
  sub_item = undefined
  if active_state then
  (
    sub_item = listItem.SubItems.add (subitem_value as string)
    sub_item.ForeColor = sub_item.ForeColor.Black
    sub_item.Font = dotnetobject "System.Drawing.Font" sub_item.Font (dotnetclass "System.Drawing.FontStyle").Regular
  )
  else
  (
    sub_item = listItem.SubItems.add ("undefined")
    sub_item.ForeColor = sub_item.ForeColor.LightGray
    sub_item.Font = dotnetobject "System.Drawing.Font" sub_item.Font (dotnetclass "System.Drawing.FontStyle").Italic
  )
  sub_item.name = subitem_name
)

fn set_sub_item listItem subitem_value subitem_name=
(
  sub_item = listItem.SubItems.Item subitem_name
  sub_item.text = subitem_value
  sub_item.ForeColor = sub_item.ForeColor.Black
  sub_item.Font = dotnetobject "System.Drawing.Font" sub_item.Font (dotnetclass "System.Drawing.FontStyle").Regular
)

fn clear_sub_item listItem subitem_name=
(
  sub_item = listItem.SubItems.Item subitem_name
  sub_item.text = "undefined"
  sub_item.ForeColor = sub_item.ForeColor.LightGray
  sub_item.Font = dotnetobject "System.Drawing.Font" sub_item.Font (dotnetclass "System.Drawing.FontStyle").Italic
)

fn get_camera_list =
(
  local camera_array = #()
  local camera_list = for obj in cameras where iskindof obj camera collect obj

  local xcount = xrefs.getXRefFileCount()
  local xref_cameras = #()
  for xindex = 1 to xcount do
  (
    xscene = xrefs.getXRefFile xindex
    local x_cameras = for obj in xscene.tree.children where iskindof obj camera collect obj
    join xref_cameras x_cameras
  )

  for cam in camera_list do
  (
    append camera_array cam
    for attr in cam.baseobject.custattributes do
    (
      if attr.name == "BatchCamAttr" then
        append camera_array (attr)
    )
  )

  join camera_array xref_cameras
  camera_array
)

fn trimLeadTrailSpaces path_string =
(
  path_string  = trimRight path_string  " "
  path_string = trimLeft path_string " "
  path_string
)

fn isNotUndefinedOrEmpty var =
(
  result = true

  if var == undefined then
    result = false
  else if (trimleft (var as string) " ") == "" then
    result = false
  result
)

fn isNotUndefined var =
(
  result = true
  if var != undefined and var != "undefined" and var != "" then
    result = true
  else
    result = false
  result
)

fn isUndefined var =
(
  result = true
  if var == undefined or var == "undefined" or var == "" then
    result = true
  else
    result = false
  result
)


fn get_render_preset_array =
(
  render_preset_array = #()
  if (maxVersion())[1] >= 11000 then  --run renderPresetMRUList command only if script is running under 3dsmax 2009+
    render_preset_array = for i in renderPresetMRUList where (i[1]!="") collect i[1]
  sort render_preset_array
  render_preset_array
)

struct BatchCameraRenderParamsStruct
(
    BatchCameraRender_frames,
    BatchCameraRender_framerange_from,
    BatchCameraRender_framerange_to,
    BatchCameraRender_anim_frame_range,
    BatchCameraRender_frame_width,
    BatchCameraRender_frame_heigth,
    BatchCameraRender_render_output,
    BatchCameraRender_elements_state,
    BatchCameraRender_not_save_elements,
    BatchCameraRender_elements_output,
    BatchCameraRender_render_preset,
    BatchCameraRender_image_aspect,
    BatchCameraRender_lastRenderPath,
    BatchCameraRender_item_index
)
--function to save variable to ini file
fn saveVar2IniFile section_name var_name var_value local_path: =
(
  INIFileDir = ""
  if (local_path != unsupplied) then
    INIFileDir = local_path
  else
    INIFileDir = ((getdir #plugcfg) + "\\BatchCameraRender\\")
  if (getDirectories INIFileDir).count == 0 then makeDir INIFileDir
  INIFilename = pathConfig.appendPath INIFileDir "BatchCameraRender.ini"
  setINISetting INIFilename section_name var_name (var_value as string)
)

--function to load variable to ini file
fn loadVarFromIniFile section_name var_name local_path: =
(
  INIFileDir = ""
  if (local_path == unsupplied) then
    INIFileDir = ((getdir #plugcfg) + "\\BatchCameraRender\\")
  else
    INIFileDir = local_path

  INIFilename = pathConfig.appendPath INIFileDir "BatchCameraRender.ini"
  temp_value = getINISetting INIFilename section_name var_name
  if temp_value == "" then undefined else temp_value
)

fn propName2Id property_name =
(
  property_id = 0
  case property_name of
  (
    "BatchCameraRender_frames":         property_id = 7801
    "BatchCameraRender_framerange_from":    property_id = 7802
    "BatchCameraRender_framerange_to":      property_id = 7803
    "BatchCameraRender_anim_frame_range":   property_id = 7804
    "BatchCameraRender_frame_width":        property_id = 7805
    "BatchCameraRender_frame_heigth":     property_id = 7806
    "BatchCameraRender_render_output":      property_id = 7807
    "BatchCameraRender_elements_state":     property_id = 7808
    "BatchCameraRender_not_save_elements":	property_id = 78081
    "BatchCameraRender_elements_output":    property_id = 7809
    "BatchCameraRender_render_preset":      property_id = 7814
    "BatchCameraRender_image_aspect":     property_id = 7829

    "BatchCameraRender_UserKey1":         property_id = 7830
    "BatchCameraRender_UserKey2":         property_id = 7831
    "BatchCameraRender_UserKey3":         property_id = 7832

    "BatchCameraRender_UserVal1":         property_id = 7833
    "BatchCameraRender_UserVal2":         property_id = 7834
    "BatchCameraRender_UserVal3":         property_id = 7835

    "BatchCameraRender_bbJobName":        property_id = 7836
    "BatchCameraRender_elementName":      property_id = 7837

    "BatchCameraRender_lastRenderPath":   property_id = 7842

    "BatchCameraRender_item_index":   property_id = 7845
  )
  property_id
)

-- setUserProp function wrapper to set dirty flag everytime user properties are affected by script
fn setUserProperty list_item property_name property_value=
(
  setAppData (list_item.tag.value) (propName2Id property_name) (property_value as string)
  setSaveRequired true --set dirt flag after setting each user property
)

--temporary helper functions
--used to correctly assign default values
fn getUserPropertyFromObject obj_itself property_name=
(
  property_value = getAppData obj_itself (propName2Id property_name)
  property_value
)

fn isFrameRangeProperty property_name=
(
  if ((property_name == "BatchCameraRender_frames") or (property_name == "BatchCameraRender_framerange_from") or \
  (property_name == "BatchCameraRender_framerange_to")  or (property_name == "BatchCameraRender_anim_frame_range")) then true else false
)

fn isFrameRangeUndefined camera_object=
(
  temp_string1 = getUserPropertyFromObject camera_object "BatchCameraRender_frames"
  temp_string2 = getUserPropertyFromObject camera_object "BatchCameraRender_framerange_from"
  temp_string3 = getUserPropertyFromObject camera_object "BatchCameraRender_framerange_to"
  temp_string5 = getUserPropertyFromObject camera_object "BatchCameraRender_anim_frame_range"

  if (isUndefined temp_string1) and (isUndefined temp_string2) and (isUndefined temp_string3) and (isUndefined temp_string5) then true else false
)
--endof temp functions. will remove them in version 2.x

fn setRootNodeData property_name property_value =
(
  if (isNotUndefinedOrEmpty (property_value as string)) then
    setAppData rootNode (propName2Id property_name) (property_value as string)
  else
    setAppData rootNode (propName2Id property_name) ""
  setSaveRequired true --set dirt flag after setting each user property
)

fn getRootNodeData property_name =
(
  data_string = ""
  data_string = batchCameraRender_getUserProperty rootNode property_name  --user standard function to add default settings ability to rootnode data
  data_string
)

fn getCameraFromCA ca_obj =
(
  local cam_obj = undefined
  if (superclassof ca_obj == AttributeDef) then
  (
    local base_obj = custattributes.getowner ca_obj
    local dep_objs = refs.dependentNodes base_obj
    if (dep_objs.count > 0) then
    (
      local temp_cam = dep_objs[1]
      if (superclassof temp_cam == camera) then
      cam_obj = temp_cam
    )
  )
  else
  (
    cam_obj = ca_obj
  )
  cam_obj
)

fn getPresetName preset_obj =
(
  local result_name = undefined
  if (superclassof preset_obj == camera) then
  (
    result_name = preset_obj.name
  )
  else
  (
    local cam_obj = getCameraFromCA preset_obj
    local preset_index = 0
    local found_obj = undefined
    for obj in cam_obj.baseobject.custattributes while found_obj == undefined do
    (
      preset_index += 1
      local num_str = formattedPrint preset_index format:"03d"
      if (obj == preset_obj) then
      (
        result_name = cam_obj.name + "_preset_" + num_str
      )
    )
  )
  result_name
)

--parser function
--replaces special keywords in string with values from argument dictionary
--dictionary syntax is (keyword, value)
fn do_modify in_string replace_start replace_end replace_text=
(
  keyword = (substring in_string replace_start replace_end)
  if keyword == "%up%" then
  (
    --handle %up% keyword
    --remove leaf from the path to point it to upper folder
    currentPath = substring in_string 1 (replace_start - 1)
    if ((pathConfig.isLegalPath currentPath) and (not (pathConfig.isRootPath currentPath))) do
      currentPath = pathConfig.removePathLeaf currentPath     --replace old path with new, truncated one.
    in_string = currentPath + (substring in_string (replace_start + keyword.count) -1)
  )
  else
  (
    in_string = replace in_string replace_start replace_end replace_text  --replace keyword with word from dictionary
  )
  in_string
)

fn parse_file_name_template input_string dictionary =
(
  found_count = 0
  found_any = false
  result_substring = input_string
  i_emergency = 0 --emergency counter - some sort of emergency stop in case of infinite loop :)
  do
  (
    i_emergency += 1
    keyword_start = findString result_substring "%"   --search for start of the keyword
    if keyword_start != undefined then
    (
      keyword_substring = substring result_substring (keyword_start+1) -1   -- remaining of the string possibly with keyword
      keyword_end = findString keyword_substring "%"  --search for end of the keyword
      found_any = true
      found_count += 1
        if keyword_end != undefined then
        (
          found_count += 1
          keyword = substring keyword_substring 1 (keyword_end-1) --exclude the keyword - since we using substring here, keyword is always as start of the string

          --replace keyword with actual value
          --get keywords and values from argument dictionary
          was_found = false --this flag remains false if none of the dictionary keywords would not equal to template keyword
          for i=1 to dictionary.count do
          (
            if keyword == dictionary[i][1] then
            (
              was_found = true  --set flag to true if keyword is found
              result_substring = do_modify result_substring keyword_start (keyword_end+1) dictionary[i][2]  --replace keyword with word from dictionary
            )
          )

          if not was_found then --if flag is not raised then replace quoted keyword with unquoted keyword
          (
            result_substring = replace result_substring keyword_start (keyword_end+1) keyword
          )
        )
        else
        (
          found_any = false --exit loop if end of keyword not found
        )
    )
    else
    (
      found_any = false
    )
  )
  while (found_any and not i_emergency > 100 )  --proceed with the loop until start or end are found
                                --or more then 100 "%" characters found
  result_substring
)

fn exec_user_val userValue=
(
  result = ""
  try
  (
    if userValue[1] == "@" then
      result = substring userValue 2 (userValue.count-1)
    else
      result = execute (userValue as string)
  )
  catch
  (
    result = "ErrUserVal"
  )
  (result as string)
)

fn compose_user_dictionary =
(
  parsing_dictionary = #()
    --user-defined keywords
  userKeyword = getRootNodeData "BatchCameraRender_UserKey1"
  userValue = getRootNodeData "BatchCameraRender_UserVal1"
  if isNotUndefinedOrEmpty userKeyword then
    append parsing_dictionary #( (userKeyword as string), (exec_user_val userValue) )

  userKeyword = getRootNodeData "BatchCameraRender_UserKey2"
  userValue = getRootNodeData "BatchCameraRender_UserVal2"
  if isNotUndefinedOrEmpty userKeyword then
    append parsing_dictionary #( (userKeyword as string), (exec_user_val userValue) )

  userKeyword = getRootNodeData "BatchCameraRender_UserKey3"
  userValue = getRootNodeData "BatchCameraRender_UserVal3"
  if isNotUndefinedOrEmpty userKeyword then
    append parsing_dictionary #( (userKeyword as string), (exec_user_val userValue) )

  parsing_dictionary
)
--function to compute global keywords, not realting to any camera object
fn compose_global_dictionary =
(
  local parsing_dictionary = #()

  --date keyword
  dateClass = (dotnetclass "System.DateTime").Now
  date_string = dateClass.ToString("yyyy-MM-dd")
  append parsing_dictionary #("date", date_string)
  --scenename keyword
  scenename_string = getFilenameFile maxFileName
  append parsing_dictionary #("scenename", scenename_string)
  --project name keyword
  projectfolder_string = pathConfig.getCurrentProjectFolder()
  append parsing_dictionary #("projectfolder", projectfolder_string)
  append parsing_dictionary #("projectpath", projectfolder_string)
  local projectname_string = pathConfig.getCurrentProjectFolder()
  if (doesFileExist projectname_string) then
    projectname_string = pathConfig.stripPathToLeaf projectname_string
  append parsing_dictionary #("projectname", projectname_string)
--  scene path keyword
  scenepath_string = maxFilePath
  scenepath_string = substring scenepath_string 1 (scenepath_string.count-1)
  append parsing_dictionary #("scenefolder", scenepath_string)
  append parsing_dictionary #("scenepath", scenepath_string)
  append parsing_dictionary #("up", "") --added to dictionary just to have parsing function call do_modify method - this keyword handling happens there.

  parsing_dictionary
)

--function to compute camera-related keywords
fn compose_parsing_dictionary camera_obj extraItems: =
(
  --compose parsing dictionary for given camera
  local parsing_dictionary = #()

  join parsing_dictionary (compose_global_dictionary())

  join parsing_dictionary (compose_user_dictionary())

  --append extra items first. they should not be the same as the ones computed in this function
  if extraItems != unsupplied then
  (
    if (classof extraItems) == Array then
    (
      for item in extraItems do
        append parsing_dictionary item
    )
  )
  --camername keyword
  local preset_name = getPresetName camera_obj
  append parsing_dictionary #("presetname", preset_name)
  local cam_obj = getCameraFromCA camera_obj
  append parsing_dictionary #("cameraname", ((cam_obj.name) as string))
  --renderpreset keyword
  append parsing_dictionary #("renderpreset", ((batchCameraRender_getUserProperty camera_obj "BatchCameraRender_render_preset") as string))
  --resolution keyword
  xres_prop = batchCameraRender_getUserProperty camera_obj "BatchCameraRender_frame_width"
  yres_prop = batchCameraRender_getUserProperty camera_obj "BatchCameraRender_frame_heigth"
  resolution_string = (xres_prop as string + "x" + yres_prop as string )
  append parsing_dictionary #("resolution", resolution_string)

  parsing_dictionary
)

--function to compute camera-related keywords. Computes render output. Should not be used in output path properties.
fn compose_full_parsing_dictionary camera_obj extraItems: =
(
  local parsing_dictionary = #()

  join parsing_dictionary (compose_parsing_dictionary camera_obj)

  --append extra items first. they should not be the same as the ones computed in this function
  if extraItems != unsupplied then
  (
    if (classof extraItems) == Array then
    (
      for item in extraItems do
        append parsing_dictionary item
    )
  )

  mainoutput = batchCameraRender_getUserProperty camera_obj "BatchCameraRender_render_output"
  if isNotUndefined mainoutput then
    mainoutput = parse_file_name_template mainoutput parsing_dictionary --parse it by using usual dictionary
  else
    mainoutput = "mainoutput"

  --exclude filename only
  mainFileNameOnly = getFilenameFile mainOutput
  --exclude path onle
  mainPath = getFilenamePath mainOutput

  append parsing_dictionary #("mainoutput", mainFileNameOnly)
  append parsing_dictionary #("renderfile", mainFileNameOnly)
  append parsing_dictionary #("mainpath", mainPath)
  append parsing_dictionary #("renderpath", mainPath)

  parsing_dictionary
)

fn getDefaultFrameRangeValue camera_object property_name =
(
  result_value = undefined

  localINI_path = maxFilePath
  if localINI_path != "" then
  (
    found_value = false
    while (not found_value) and (localINI_path != "") do
    (
      localINI_file = pathConfig.appendPath localINI_path "BatchCameraRender.ini"
      if (doesFileExist localINI_file) then
      (
        --get the framerange value from the local ini file.
        framerange_data1 = loadVarFromIniFile "Default Settings" "BatchCameraRender_frames"        local_path:localINI_path
        framerange_data2 = loadVarFromIniFile "Default Settings" "BatchCameraRender_framerange_from"   local_path:localINI_path
        framerange_data3 = loadVarFromIniFile "Default Settings" "BatchCameraRender_framerange_to"     local_path:localINI_path
        framerange_data4 = loadVarFromIniFile "Default Settings" "BatchCameraRender_anim_frame_range"  local_path:localINI_path

        found_value = case of
        (
          (isNotUndefined framerange_data1): true
          (isNotUndefined framerange_data2): true
          (isNotUndefined framerange_data3): true
          (isNotUndefined framerange_data4): true
          default: false
        )
        if (found_value) then
          result_value = loadVarFromIniFile "Default Settings" property_name local_path:localINI_path
      )
      if (not found_value) then
        localINI_path = pathConfig.removePathLeaf localINI_path --move to upper folder if ini file not found OR value in found ini file not found
    )
    if (not found_value) then
      result_value = loadVarFromIniFile "Default Settings" property_name
  )
  else  --if local path is invalid
    result_value = loadVarFromIniFile "Default Settings" property_name

  result_value
)

--get default value for the property from the global or local ini files
fn getDefaultValue camera_object property_name =
(
  result_value = undefined
  --try to find local ini file recursively starting from scene folder and down to root folder.
  --check each file if it contains default value
  --if none of them contains default value, fall to the global ini file
  localINI_path = maxFilePath
  if localINI_path != "" then
  (
    found_value = false
    while (not found_value) and (localINI_path != "") do
    (
      localINI_file = pathConfig.appendPath localINI_path "BatchCameraRender.ini"
      if (doesFileExist localINI_file) then
      (
        result_value = loadVarFromIniFile "Default Settings" property_name local_path:localINI_path
        if (isNotUndefined result_value) then
          found_value = true
      )
      if (not found_value) then
        localINI_path = pathConfig.removePathLeaf localINI_path --move to upper folder if ini file not found OR value in found ini file not found
    )
    if (not found_value) then
      result_value = loadVarFromIniFile "Default Settings" property_name
  )
  else
    result_value = loadVarFromIniFile "Default Settings" property_name

  result_value
)

--getUserProp wrapper to change property saving mechanism in future
--to change it from user properties to appdata
--also added default value mechanism
fn getUserProperty camera_object property_name=
(
  if (camera_object != undefined) then
  (
    property_value = getAppData camera_object (propName2Id property_name)

    if (isUndefined property_value) then --try to read default setting from the INI file.
    (
      --if the property is frame range property check all other frame range properties and only if all that properties are undefined return default property.
      if (isFrameRangeProperty property_name) then
      (
        if (isFrameRangeUndefined camera_object) then --if frame range is undefined in object's data get it from the default
          property_value = getDefaultFrameRangeValue camera_object property_name
      )
      else
        property_value = getDefaultValue camera_object property_name
    )
    (if (isNotUndefined property_value) then property_value else undefined)
  )
)
batchCameraRender_getUserProperty = getUserProperty

fn saveDefaultValues camera_object property_names =
(
  try
    ini_file_name = getSaveFileName caption:"INI File Name" filename:"BatchCameraRender.ini" types:"INI files (*.ini)|*.ini|All files (*.*)|*.*|" historyCategory:"Scripts"
  catch (getCurrentException())

  if ini_file_name != undefined then
  (
    ini_file_path = getFilenamePath ini_file_name
    for property_name in property_names do
    (
      property_value = getUserProperty camera_object property_name
      saveVar2IniFile "Default Settings" property_name (property_value as string) local_path:ini_file_path
    )
  )
)

fn isPathAbsolute path_string =
(
  pathConfig.isUncPath path_string or  pathConfig.isPathRootedAtDriveLetter path_string
)

--function to switch render buttons' activity state
fn render_buttons_active state =
(
  --main section
  batchCameraRender_mainRollOut.render_start.enabled = state
)

--function to switch window element's activity state
fn elements_active state =
(
  batchCameraRender_mainRollOut.select_camera.enabled = state
  batchCameraRender_mainRollOut.set_viewport.enabled = state
  batchCameraRender_mainRollOut.check_selected.enabled = state

  if (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Count == 1) then
  (
    batchCameraRender_mainRollOut.copy_button.enabled = true
    batchCameraRender_mainRollOut.add_button.enabled = ((superclassof (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Item[0].tag.value) == camera))
  )
  else
  (
    batchCameraRender_mainRollOut.copy_button.enabled = false
    batchCameraRender_mainRollOut.add_button.enabled = false
  )

  if (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Count > 0) then
  (
    batchCameraRender_mainRollOut.paste_button.enabled = (BatchCamRenderParamsBuffer != undefined)
    batchCameraRender_mainRollOut.remove_button.enabled = true
  )
  else
  (
    batchCameraRender_mainRollOut.paste_button.enabled = false
    batchCameraRender_mainRollOut.remove_button.enabled = false
  )

  --output section
  for control_element in Render_Output_Rollout.controls do
    control_element.enabled = state

  --frame range section
  for control_element in Frame_Range_Rollout.controls do
    control_element.enabled = state

  --resolution section
  for control_element in Output_Size_Rollout.controls do
    control_element.enabled = state
  if Output_Size_Rollout.lock_aspect.checked then
    Output_Size_Rollout.image_aspect_spinner.enabled = false
)

--function to set all elements "enabled" state depending on list item's selection
fn ui_elements_refresh listview_obj =
(
  --if there's no elements in list then deactivate all elements
  if listview_obj.Items.count == 0 then
  (
    --no camera in scene
    --deactivate render buttons
    render_buttons_active false
    elements_active false
    --and all other elements too
    for control_element in batchCameraRender_mainRollOut.controls do
    (
      case (control_element.name) of
      (
        "Refresh":  control_element.enabled = true
        default:    control_element.enabled = false
      )
    )
  )
  else  --if there is something...
  (
    --make listview active
    for control_element in batchCameraRender_mainRollOut.controls do
    (
      if control_element.name == "paste_button" then
        control_element.enabled = (BatchCamRenderParamsBuffer != undefined)
      else
        control_element.enabled = true
    )

    --if something is checked then activate render buttons
    render_buttons_active (listview_obj.CheckedItems.Count > 0)

    --if something selected activate all elements and fill some fields
    elements_active (listview_obj.SelectedItems.count > 0)

    if listview_obj.SelectedItems.count > 1 then
    (
      batchCameraRender_mainRollOut.set_viewport.enabled = false
    )
  )
)

fn leadingZero num digitCount=
(
  str = num as string
  while str.count < digitCount do
    str = "0" + str
  str
)

--returns the array of animation frames from object's
fn get_key_array obj=
(
  frame_array = #()
  --standard transformation section
  try
    if obj.pos.controller.keys.count > 0 then
      frame_array = frame_array + (for i in obj.pos.controller.keys collect i.time)
  catch ()
  try
    if obj.rotation.controller.keys.count > 0 then
      frame_array = frame_array + (for i in obj.rotation.controller.keys collect i.time)
  catch ()
  try
    if obj.scale.controller.keys.count > 0 then
      frame_array = frame_array + (for i in obj.scale.controller.keys collect i.time)
  catch ()

  --object properties section
  prop_controller_array = for prop in getPropNames obj where isPropertyAnimatable obj prop collect (getPropertyController obj prop) --get controllers
  prop_controller_array = for prop in prop_controller_array where prop != undefined collect prop  --collect only existing controller
  if prop_controller_array.count > 0 then
    for controller in prop_controller_array do
    (
      key_array = controller.keys
      if key_array.count > 0 then
        frame_array = frame_array + (for i in key_array collect i.time)
    )

  --object modifers section
  if obj.modifiers.count > 0 then
    for one_modifier in obj.modifiers do
    (
      modifier_controller_array = for prop in getPropNames one_modifier where isPropertyAnimatable one_modifier prop collect (getPropertyController one_modifier prop)
      modifier_controller_array  = for prop in modifier_controller_array where prop != undefined collect prop
      if modifier_controller_array.count > 0 then
        for controller in modifier_controller_array do
        (
          key_array = controller.keys
          if key_array.count > 0 then
            frame_array = frame_array + (for i in key_array collect i.time)
        )
    )

  frame_array
)

--function to get the whole range of animation for camera and target objects
fn get_key_range camera_obj=
(
  local camera_keys = #()
  local target_keys = #()
  camera_keys = get_key_array camera_obj
  if camera_obj.target != undefined then
    target_keys = get_key_array (camera_obj.target)
  full_range = camera_keys + target_keys

  result = #()
  if full_range.count > 0 then
  (
    append result (amin full_range)
    append result (amax full_range)
  )
  else
  (
    result = #(0f, 0f)
  )
  result
)

fn fill_ListView listview_obj camera_list =
(
  --fill in spreadshit dotNet version
  ItemsArray = #() --array to collect the list items
  ItemsIndexArray = #() --array to collect the list items

  for camera_obj in camera_list do
  (
    local preset_name = getPresetName camera_obj
    li = dotNetObject "System.Windows.Forms.ListViewItem" preset_name
    li.tag = dotNetMXSValue camera_obj
    li.UseItemStyleForSubItems = false
    sub_li = undefined --subitem variable
    --get framerange
    temp_string1 = getUserProperty camera_obj "BatchCameraRender_frames"
    temp_string2 = getUserProperty camera_obj "BatchCameraRender_framerange_from"
    temp_string3 = getUserProperty camera_obj "BatchCameraRender_framerange_to"
    temp_string5 = getUserProperty camera_obj "BatchCameraRender_anim_frame_range"

    if isNotUndefined temp_string5 then
    ( --render_frames
      temp_frame_range = get_key_range camera_obj
      frame_from = temp_frame_range[1].frame as string
      frame_to = temp_frame_range[2].frame as string

      add_sub_item li ("anim.range:" + (frame_from as integer) as string + "..." + (frame_to as integer) as string) "frames" true
    )
    else if isNotUndefined temp_string1 then
    ( --render_frames
      add_sub_item li (temp_string1 as string) "frames" true
    )
    else if isNotUndefined temp_string2 then
    (
      if (temp_string2 as integer == temp_string3 as integer) then  --single frame
        add_sub_item li (temp_string2 as string) "frames" true
      else  --frame range
        add_sub_item li (temp_string2 as string + "..." + temp_string3 as string) "frames" true
    )
    else
    (
      add_sub_item li "undefined" "frames" false
    )

    --get frame size
    xres_prop = getUserProperty camera_obj "BatchCameraRender_frame_width"
    yres_prop = getUserProperty camera_obj "BatchCameraRender_frame_heigth"
    if  (isNotUndefined xres_prop) and (isNotUndefined yres_prop) then
      add_sub_item li (xres_prop as string + " x " + yres_prop as string) "resolution" true
    else
      add_sub_item li "undefined" "resolution" false

    image_aspect = getUserProperty camera_obj "BatchCameraRender_image_aspect"
    if  (isNotUndefined image_aspect) and (isNotUndefined image_aspect) then
      add_sub_item li (image_aspect as string) "image_aspect" true
    else
      add_sub_item li "undefined" "image_aspect" false

    --get filename
    temp_string = getUserProperty camera_obj "BatchCameraRender_render_output"
    if isNotUndefined temp_string then
      add_sub_item li temp_string "path" true
    else
      add_sub_item li "undefined" "path" false

    --get elements' state
    temp_string = getUserProperty camera_obj "BatchCameraRender_elements_state"
    if  isNotUndefined temp_string then
      add_sub_item li (temp_string as string) "elements_state" true
    else
      add_sub_item li "undefined" "elements_state" false

    --get not_save_elements
    temp_string = getUserProperty camera_obj "BatchCameraRender_not_save_elements"
    if isNotUndefined temp_string then
      add_sub_item li (temp_string as string) "not_save_elements" true
    else
      add_sub_item li "undefined" "not_save_elements" false

    --get elements' path
    temp_string = getUserProperty camera_obj "BatchCameraRender_elements_output"
    if  isNotUndefined temp_string then
      add_sub_item li (temp_string as string) "elements_path" true
    else
      add_sub_item li "undefined" "elements_path" false

    --render preset part
    temp_string = getUserProperty camera_obj "BatchCameraRender_render_preset"
    if isNotUndefined temp_string then
      add_sub_item li temp_string "render_preset" true
    else
      add_sub_item li "undefined" "render_preset" false

    --restore listitem's index
    local itemIndex = -1
    temp_string = getUserProperty camera_obj "BatchCameraRender_item_index"
    if isNotUndefined temp_string then
      itemIndex = (temp_string as integer)

    append ItemsArray #(li, itemIndex) --we add the list item to the array
  )

  fn compareFN item1 item2 =
  (
    local res
    if item1[2] == -1 or item2[2] == -1 then
    (
      res = case of
      (
        (item1[1].text < item2[1].text): -1
        (item1[1].text > item2[1].text): 1
        default: 0
      )
    )
    else
    (
      res = case of
      (
        (item1[2] < item2[2]): -1
        (item1[2] > item2[2]): 1
        default: 0
      )
    )
    res
  )

  qsort ItemsArray compareFN

  ItemsArray = for item in ItemsArray collect item[1]

  global batchCameraRender_loading_items = true
  listview_obj.Items.AddRange ItemsArray

)


fn init_ListView listview_obj camera_list =
(
  --dotNet object initialization
  listview_obj.GridLines = true
  listview_obj.CheckBoxes = true
  listview_obj.Sorting = (dotNetClass "System.Windows.Forms.SortOrder").None
  listview_obj.HeaderStyle = (dotNetClass "System.Windows.Forms.ColumnHeaderStyle").NonClickable
  listview_obj.View = (dotNetClass "System.Windows.Forms.View").Details
  listview_obj.FullRowSelect = true
  listview_obj.HideSelection = false
  listview_obj.AutoArrange = false

  listview_obj.AllowDrop = true

  listview_obj.BeginUpdate()

  listview_obj.Columns.Clear()

  standard_columns = #("Camera", "Frames", "Resolution", "Aspect", "Path", "Elements State", "Elements Path", "Render Preset")
  for i in standard_columns do
    listview_obj.Columns.add i

  if camera_list.count > 0 then
  (
    listview_obj.Items.Clear()
    fill_ListView listview_obj camera_list

    listview_obj.AutoResizeColumns (dotNetClass "System.Windows.Forms.ColumnHeaderAutoResizeStyle").HeaderSize
    listview_obj.Refresh()
  )
  else
  (
    listview_obj.Items.Clear()
  )

  --code to restore list items' checked state
  --placed here to work with already sorted list of dotnet control items
  --initialize state varialble if it is undefined or if camera count doesn't match with state's count
  if BatchCam_listItem_state == undefined then
    BatchCam_listItem_state = #() --create empty array if there's no state array
  BatchCam_listItem_state.count = camera_list.count --match count
  --iterate over dotnet list items
  for i=1 to listview_obj.Items.count do
  (
    if BatchCam_listItem_state[i] == true then    --if item's state saved then check it in list
      listview_obj.Items.Item[i-1].checked = true
    else                              --else - if item's state is false or UNDEFINED then save state as false and uncheck the item
    (
      BatchCam_listItem_state[i] = false
      listview_obj.Items.Item[i-1].checked = false
    )
  )
  listview_obj.EndUpdate()
)

fn batchCameraRender_reset_render_counter=
(
  -- no-op (Try_Counter removed)
)

--reload all cameras
fn batchCameraRender_reload_cameras lv_objects =
(
  selectionArray = for i=0 to (lv_objects.SelectedIndices.Count-1) collect lv_objects.SelectedIndices.Item[i]
  init_ListView lv_objects (get_camera_list())
  for i in selectionArray do
  (
    if not i > (lv_objects.Items.Count-1) then
      (lv_objects.Items.Item[i]).Selected = true
  )

  LV_ITEMS = #()  --this array contains listview items for convinience
  for i=0 to (lv_objects.Items.Count - 1) do
    append LV_ITEMS (lv_objects.Items.Item i)

  --refresh ui elements
  if (lv_objects.items.count == 0) then --only call refresh if empty listview, because init_ListView/fill_ListView will refresh anyway
    ui_elements_refresh lv_objects
)
