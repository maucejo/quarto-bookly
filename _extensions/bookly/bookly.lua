-- bookly.lua
-- Handles book structure for bookly Typst format:
--   • Part dividers  → #part[...]
--   • First appendix → state update + #show: appendix

local function is_typst_book()
  local file_state = quarto.doc.file_metadata()
  return quarto.doc.is_format("typst") and
         file_state ~= nil and
         file_state.file ~= nil
end

local function map_callout_to_bookly_box(classes)
  for _, cls in ipairs(classes) do
    local kind = cls:match("^callout%-(.+)$")
    if kind and kind ~= "callout" then
      if kind == "note" then
        return "info-box"
      elseif kind == "tip" then
        return "tip-box"
      elseif kind == "warning" then
        return "warning-box"
      elseif kind == "important" then
        return "important-box"
      elseif kind == "question" then
        return "question-box"
      elseif kind == "caution" then
        return "warning-box"
      end
    end
  end
  return nil
end

local function callout_filter_div(el)
  if not is_typst_book() then
    return nil
  end

  local box_name = map_callout_to_bookly_box(el.classes)
  if box_name == nil then
    return nil
  end

  -- Drop the synthetic heading title (e.g. "## Note") because bookly boxes
  -- already provide a localized/default title.
  local content = el.content
  if #content > 0 and content[1].t == "Header" then
    content:remove(1)
  end

  local body_typst = pandoc.write(pandoc.Pandoc(content), "typst")
  local typst = "#" .. box_name .. "[\n" .. body_typst .. "\n]"
  return pandoc.RawBlock("typst", typst)
end

local header_filter = {
  Div = callout_filter_div,
  Header = function(el)
    if not is_typst_book() then
      return nil
    end

    local file_state = quarto.doc.file_metadata()
    if file_state == nil or file_state.file == nil then
      return nil
    end

    local file = file_state.file
    local bookItemType = file.bookItemType

    -- Only handle level-1 headings with a bookItemType
    if el.level ~= 1 or bookItemType == nil then
      return nil
    end

    -- ── Part divider ──────────────────────────────────────────────────────────
    if bookItemType == "part" then
      return pandoc.RawBlock('typst',
        '#part[' .. pandoc.utils.stringify(el.content) .. ']')
    end

    -- ── First appendix ────────────────────────────────────────────────────────
    if bookItemType == "appendix" then
      if file.bookItemNumber == 1 or file.bookItemNumber == nil then
        -- Update numbering state and switch bookly to appendix mode
        local appendixStart = pandoc.RawBlock('typst',
          '#_bookly-in-appendix.update(true)\n#show: appendix')

        -- Quarto may emit a synthetic unnumbered "Appendices" divider heading.
        -- Replace it with a bookly-compatible unnumbered heading.
        if el.classes:includes("unnumbered") then
          local language = quarto.doc.language
          local appendicesTitle = (language and
            language["section-title-appendices"]) or "Appendices"
          local appendicesHeading = pandoc.RawBlock('typst',
            '#heading(level: 1, numbering: none)[' .. appendicesTitle .. ']')
          return { appendixStart, appendicesHeading }
        end

        return { appendixStart, el }
      end
    end

    return nil
  end
}

-- Combine with file_metadata_filter so bookItemType is populated
-- during this filter's document traversal
return quarto.utils.combineFilters({
  quarto.utils.file_metadata_filter(),
  header_filter
})
