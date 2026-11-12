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

-- ── Raw Typst metadata ──────────────────────────────────────────────────────
-- Options such as colors.primary or config-options.<key> hold Typst code
-- (e.g. rgb("#1d90d0").darken(15%)). Pandoc parses metadata strings as
-- Markdown and escapes them when writing Typst (`#` → `\#`), which breaks
-- compilation. Convert these values to raw Typst so they pass through as-is.
-- A bare hex color ("#1d90d0") is accepted as a shortcut for rgb("#1d90d0").

local function to_raw_typst(value)
  local t = pandoc.utils.type(value)
  if t ~= "Inlines" and t ~= "Blocks" and t ~= "string" then
    return value -- booleans, lists, maps... are left untouched
  end
  local code
  if t == "string" then
    code = value
  else
    -- Undo smart-quote parsing (`"` → Quoted / curly quotes) and flatten
    -- to plain text so nothing is escaped.
    local blocks = t == "Blocks" and value or pandoc.Blocks({ pandoc.Plain(value) })
    blocks = blocks:walk({
      Quoted = function(q)
        local mark = q.quotetype == "SingleQuote" and "'" or '"'
        local out = pandoc.Inlines({ pandoc.Str(mark) })
        out:extend(q.content)
        out:insert(pandoc.Str(mark))
        return out
      end,
      Str = function(s)
        local txt = s.text:gsub("[“”]", '"'):gsub("[‘’]", "'")
        return pandoc.Str(txt)
      end,
    })
    code = pandoc.utils.stringify(blocks)
  end
  code = code:gsub("^%s+", ""):gsub("%s+$", "")
  if code:match("^#%x+$") then
    code = 'rgb("' .. code .. '")'
  end
  return pandoc.Inlines({ pandoc.RawInline("typst", code) })
end

local raw_typst_keys = {
  "colors", "bookly-colors", "config-options", "bookly-config-options",
}

local meta_filter = {
  Meta = function(meta)
    if not quarto.doc.is_format("typst") then
      return nil
    end
    for _, key in ipairs(raw_typst_keys) do
      local map = meta[key]
      if map ~= nil and pandoc.utils.type(map) == "table" then
        for k, v in pairs(map) do
          map[k] = to_raw_typst(v)
        end
        meta[key] = map
      end
    end

    -- Title page: `bookly-title-page` is an alias of `title-page`.
    -- `style: thesis` selects thesis-title-page (template needs a flag,
    -- as Pandoc templates cannot compare strings); default is book.
    local tp = meta["title-page"] or meta["bookly-title-page"]
    if tp ~= nil and pandoc.utils.type(tp) == "table" then
      local style = tp.style and pandoc.utils.stringify(tp.style) or "book"
      tp.style = nil
      if style == "thesis" then
        tp.thesis = true
      end
      -- Paths and identifiers must not be Markdown-escaped
      for _, k in ipairs({ "cover", "logo", "type" }) do
        if tp[k] ~= nil then
          tp[k] = to_raw_typst(tp[k])
        end
      end
      meta["title-page"] = tp
    end
    return meta
  end
}

-- Combine with file_metadata_filter so bookItemType is populated
-- during this filter's document traversal
return quarto.utils.combineFilters({
  quarto.utils.file_metadata_filter(),
  header_filter,
  meta_filter
})
