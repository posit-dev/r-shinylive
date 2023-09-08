local hasDoneShinyliveSetup = false
local codeblockScript = nil

-- Try calling `pandoc.pipe('shinylive', ...)` and if it fails, print a message
-- about installing shinylive python package.
function callPythonShinylive(args, input)
  local res
  local status, err = pcall(
    function()
      res = pandoc.pipe("shinylive", args, input)
    end
  )

  if not status then
    print(err)
    error("Error running 'shinylive' command. Perhaps you need to install the 'shinylive' Python package?")
  end

  return res
end

-- Try calling `pandoc.pipe('Rscript', ...)` and if it fails, print a message
-- about installing shinylive R package.
function callRShinylive(args, input)
  args = { "-e",
    -- TODO-barret; Remove load_all()
    -- "shinylive::quarto_ext()",
    "pkgload::load_all('../../', quiet = TRUE); shinylive::quarto_ext()",
    table.unpack(args) }
  local res
  local status, err = pcall(
    function()
      res = pandoc.pipe("Rscript", args, input)
    end
  )

  if not status then
    print(err)
    error(
      "Error running 'Rscript' command. Perhaps you need to install the 'shinylive' R package?")
  end

  return res
end

function callShinylive(language, args, input)
  -- print("Calling " .. language .. " shinylive with args: " .. table.concat(args, " "))
  if language == "python" then
    return callPythonShinylive(args, input)
  elseif language == "r" then
    return callRShinylive(args, input)
  else
    error("Unknown language: " .. language)
  end
end

-- Do one-time setup when a Shinylive codeblock is encountered.
function ensureShinyliveSetup(language)
  if hasDoneShinyliveSetup then
    return
  end
  hasDoneShinyliveSetup = true

  -- Find the path to codeblock-to-json.ts and save it for later use.
  codeblockScript = callShinylive(language, { "codeblock-to-json-path" }, "")
  -- Remove trailing whitespace
  codeblockScript = codeblockScript:gsub("%s+$", "")

  local baseDeps = getShinyliveBaseDeps(language)
  for idx, dep in ipairs(baseDeps) do
    quarto.doc.add_html_dependency(dep)
  end

  quarto.doc.add_html_dependency(
    {
      name = "shinylive-quarto-css",
      stylesheets = { "resources/css/shinylive-quarto.css" }
    }
  )
end

function getShinyliveBaseDeps(language)
  -- Relative path from the current page to the root of the site. This is needed
  -- to find out where shinylive-sw.js is, relative to the current page.
  if quarto.project.offset == nil then
    error("The shinylive extension must be used in a Quarto project directory (with a _quarto.yml file).")
  end
  local depJson = callShinylive(
    language,
    { "base-deps", "--sw-dir", quarto.project.offset },
    ""
  )

  local deps = quarto.json.decode(depJson)
  return deps
end

return {
  {
    CodeBlock = function(el)
      if el.attr and (
            el.attr.classes:includes("{shinylive-python}")
            or el.attr.classes:includes("{shinylive-r}")
          ) then
        local language = "python"
        if el.attr.classes:includes("{shinylive-r}") then
          language = "r"
        end
        ensureShinyliveSetup(language)

        -- Convert code block to JSON string in the same format as app.json.
        local parsedCodeblockJson = pandoc.pipe(
          "quarto",
          { "run", codeblockScript },
          el.text
        )

        -- This contains "files" and "quartoArgs" keys.
        local parsedCodeblock = quarto.json.decode(parsedCodeblockJson)

        -- Find Python package dependencies for the current app.
        local appDepsJson = callShinylive(
          language,
          { "package-deps" },
          quarto.json.encode(parsedCodeblock["files"])
        )

        local appDeps = quarto.json.decode(appDepsJson)

        for idx, dep in ipairs(appDeps) do
          quarto.doc.attach_to_dependency("shinylive", dep)
        end

        if el.attr.classes:includes("{shinylive-python}") then
          el.attributes.engine = "python"
          el.attr.classes = pandoc.List()
          el.attr.classes:insert("shinylive-python")
        elseif el.attr.classes:includes("{shinylive-r}") then
          el.attributes.engine = "r"
          el.attr.classes = pandoc.List()
          el.attr.classes:insert("shinylive-r")
        end
        return el
      end
    end
  }
}
