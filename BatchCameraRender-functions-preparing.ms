--########################--
--FUNCTIONS for batch camera render script
--Functions to prepare scene for the rendering,
--to get properties from camera objects and set
--them to render dialog
--########################--
struct BatchCam_RenderParameterStore
(
  old_rendUseActiveView,
  viewport_type,
  old_camera,
  oldrendType,
  oldrendStart,
  oldrendEnd,
  oldrendPickupFrames,
  oldrendNThFrame,
  oldrenderWidth,
  oldrenderHeight,
  oldfilename,
  oldsavestate,
  numOfElements,
  oldElementsFullPaths,
  oldElementsState,
  oldRenderType
)

fn storeRenderParams buffer=
(
  buffer.old_rendUseActiveView = rendUseActiveView
  buffer.viewport_type = viewport.getType()
  if buffer.viewport_type == #view_camera then
    buffer.old_camera = viewport.getCamera()
  buffer.oldrendType = rendTimeType
  buffer.oldrendStart = rendStart
  buffer.oldrendEnd = rendEnd
  buffer.oldrendPickupFrames = rendPickupFrames
  buffer.oldrendNThFrame = rendNThFrame
  buffer.oldrenderWidth = renderWidth
  buffer.oldrenderHeight = renderHeight
  buffer.oldfilename = rendOutputFilename
  buffer.oldsavestate = rendSaveFile
  buffer.oldRenderType = getRenderType()

  elementMgr = maxOps.GetCurRenderElementMgr()
  buffer.numOfElements = elementMgr.NumRenderElements()
  buffer.oldElementsFullPaths = #()
  for index=0 to (buffer.numOfElements-1) do
  (
    tempPath = elementMgr.getrenderelementfilename index
    if tempPath != undefined then
      append buffer.oldElementsFullPaths tempPath
    else
      append buffer.oldElementsFullPaths ""
  )
  buffer.oldElementsState = elementMgr.GetElementsActive()
  buffer
)

fn restoreRenderParams buffer=
(
    rendUseActiveView = buffer.old_rendUseActiveView
    rendTimeType = buffer.oldrendType
    rendStart = buffer.oldrendStart
    rendEnd = buffer.oldrendEnd
    rendPickupFrames = buffer.oldrendPickupFrames
    rendNThFrame = buffer.oldrendNThFrame
    renderWidth = buffer.oldrenderWidth
    renderHeight = buffer.oldrenderHeight
    rendOutputFilename = buffer.oldfilename
    rendSaveFile = buffer.oldsavestate
    elementMgr = maxOps.GetCurRenderElementMgr()
    for index=0 to (buffer.numOfElements-1) do
      elementMgr.setRenderElementFilename index buffer.oldElementsFullPaths[index+1]
    elementMgr.SetElementsActive buffer.oldElementsState

    setRenderType (buffer.oldRenderType)

    --restore viewport type and camera
    if buffer.viewport_type == #view_camera then
      viewport.setCamera buffer.old_camera
    else
      viewport.setType buffer.viewport_type
)

fn prepare_render_elements camera_to_render=
(
  local elements_state = getUserProperty camera_to_render "BatchCameraRender_elements_state"
  local not_save_elements = getUserProperty camera_to_render "BatchCameraRender_not_save_elements"

  elementsFullPath = undefined
  if (isNotUndefined elements_state) then
  (
    if (isNotUndefined not_save_elements) and (not_save_elements as booleanClass) then
    (
      elementMgr = maxOps.GetCurRenderElementMgr()
      numOfElements = elementMgr.NumRenderElements()
      if numOfElements != 0 do
      for index=0 to numOfElements-1 do
      (
        elementMgr.SetRenderElementFilename index ""
      )
      elementsFullPath = ""
    )
    else
    (
      elementMgr = maxOps.GetCurRenderElementMgr()
      if shouldBeSaved() and (elements_state as booleanClass) then
      (
        elementMgr.SetElementsActive true

        numOfElements = elementMgr.NumRenderElements()
        if numOfElements != 0 then
        (
          for index=0 to (numOfElements-1) do
          (
            --get element's path
            element = elementMgr.getrenderelement index
            --extract element name
            elementNameParts = filterString (element as string) ":"
            elementType = elementNameParts[2] as string
            elementName = element.elementName
            syntaxExtraItems = #(#("elementtype", (elementType as string)), #("elementname", (elementName as string)))

            --make new file path
            mainOutput = rendOutputFilename
            mainPath = getFilenamePath mainOutput
            mainFileNameOnly = getFilenameFile mainOutput
            mainFileType = getFilenameType mainOutput

            newPath = getUserProperty camera_to_render "BatchCameraRender_elements_output"
            if (isNotUndefined newPath) then
            (
              newPath = parse_file_name_template newPath (compose_full_parsing_dictionary camera_to_render extraItems:syntaxExtraItems)
            )
            else
            (
              newPath = mainPath  --Use elements path same as main output if elements path is empty. May be warning message will be useful here.
            )

            elementNamePattern = getRootNodeData "BatchCameraRender_elementName"
            if (isNotUndefinedOrEmpty elementNamePattern) then
            (
              elementsFileName = parse_file_name_template elementNamePattern (compose_full_parsing_dictionary camera_to_render extraItems:syntaxExtraItems)
            )
            else
              elementsFileName = mainFileNameOnly + "_" +  elementType + "_" + elementName

            elementsFileName += mainFileType

            if (isPathAbsolute newPath) then
            (
              --use absolute path + existing or composed file name
              elementsFullPath = pathConfig.appendPath newPath elementsFileName
            )
            else
            (
              --if subfolder then add subfolder to main path
              elementsNewPath = pathConfig.appendPath mainPath newPath  --path is main + elements subfolder
              elementsFullPath = pathConfig.appendPath elementsNewPath elementsFileName
            )

            --check if the path (without filename) exist
            temp_path = getFilenamePath elementsFullPath
            if (not (doesFileExist temp_path)) then
            (
              --always create paths silently
              if not makeDir temp_path all:true then
                throw ("Failed to create path: "+ temp_path)
            )
            --set new path to element
            elementMgr.setRenderElementFilename index elementsFullPath
          )
        )
      )
      else
      (
        elementMgr.SetElementsActive false
      )
    )
  )
  elementsFullPath
)

fn checkAndAppendMainPath path_string =
(
  mainOutput = rendOutputFilename
  mainPath = getFilenamePath mainOutput

  fullPath = ""

  if (isPathAbsolute path_string) then
    fullPath = path_string
  else
    --if subfolder then add subfolder to main path
    fullPath = pathConfig.appendPath mainPath path_string --path is main + elements subfolder

  return fullPath
)
