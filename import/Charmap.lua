-- FireRed's custom text encoding, byte -> character. Generated from the
-- pokefirered-master decomp's own charmap.txt (its text-encoding reference,
-- not ROM-extracted binary content -- see PARITY_CONTRACT.md's no-ROM rule,
-- which is about compiled/binary game assets, not this kind of crosswalk
-- table, the same category as the struct-offset knowledge already used
-- throughout import/*.lua).
--
-- Only single-character mappings are included (charmap.txt also has
-- multi-byte control-code macros like SE_M_SCREECH, which are not text and
-- are out of scope here). Where charmap.txt defines a byte twice (a small
-- number of entries, e.g. 0xAE as both '-' and 'ー'), the first definition
-- in the file wins, matching charmap.txt's own declaration order.
--
-- 0xFF is FireRed's string terminator in most contexts (name tables, etc.)
-- even though charmap.txt also lists it as the literal '$' character used
-- in a few money-display strings; Charmap.decode() stops there by default.

local BYTE_TO_CHAR = {
  [0x00] = " ",
  [0x01] = "À",
  [0x02] = "Á",
  [0x03] = "Â",
  [0x04] = "Ç",
  [0x05] = "È",
  [0x06] = "É",
  [0x07] = "Ê",
  [0x08] = "Ë",
  [0x09] = "Ì",
  [0x0A] = "こ",
  [0x0B] = "Î",
  [0x0C] = "Ï",
  [0x0D] = "Ò",
  [0x0E] = "Ó",
  [0x0F] = "Ô",
  [0x10] = "Œ",
  [0x11] = "Ù",
  [0x12] = "Ú",
  [0x13] = "Û",
  [0x14] = "Ñ",
  [0x15] = "ß",
  [0x16] = "à",
  [0x17] = "á",
  [0x18] = "ね",
  [0x19] = "ç",
  [0x1A] = "è",
  [0x1B] = "é",
  [0x1C] = "ê",
  [0x1D] = "ë",
  [0x1E] = "ì",
  [0x1F] = "ま",
  [0x20] = "î",
  [0x21] = "ï",
  [0x22] = "ò",
  [0x23] = "ó",
  [0x24] = "ô",
  [0x25] = "œ",
  [0x26] = "ù",
  [0x27] = "ú",
  [0x28] = "û",
  [0x29] = "ñ",
  [0x2A] = "º",
  [0x2B] = "ª",
  [0x2C] = "わ",
  [0x2D] = "&",
  [0x2E] = "+",
  [0x2F] = "ぁ",
  [0x30] = "ぃ",
  [0x31] = "ぅ",
  [0x32] = "ぇ",
  [0x33] = "ぉ",
  [0x34] = "ゃ",
  [0x35] = "=",
  [0x36] = ";",
  [0x37] = "が",
  [0x38] = "ぎ",
  [0x39] = "ぐ",
  [0x3A] = "げ",
  [0x3B] = "ご",
  [0x3C] = "ざ",
  [0x3D] = "じ",
  [0x3E] = "ず",
  [0x3F] = "ぜ",
  [0x40] = "ぞ",
  [0x41] = "だ",
  [0x42] = "ぢ",
  [0x43] = "づ",
  [0x44] = "で",
  [0x45] = "ど",
  [0x46] = "ば",
  [0x47] = "び",
  [0x48] = "ぶ",
  [0x49] = "べ",
  [0x4A] = "ぼ",
  [0x4B] = "ぱ",
  [0x4C] = "ぴ",
  [0x4D] = "ぷ",
  [0x4E] = "ぺ",
  [0x4F] = "ぽ",
  [0x50] = "っ",
  [0x51] = "¿",
  [0x52] = "¡",
  [0x53] = "ウ",
  [0x54] = "エ",
  [0x55] = "オ",
  [0x56] = "カ",
  [0x57] = "キ",
  [0x58] = "ク",
  [0x59] = "ケ",
  [0x5A] = "Í",
  [0x5B] = "%",
  [0x5C] = "(",
  [0x5D] = ")",
  [0x5E] = "セ",
  [0x5F] = "ソ",
  [0x60] = "タ",
  [0x61] = "チ",
  [0x62] = "ツ",
  [0x63] = "テ",
  [0x64] = "ト",
  [0x65] = "ナ",
  [0x66] = "ニ",
  [0x67] = "ヌ",
  [0x68] = "â",
  [0x69] = "ノ",
  [0x6A] = "ハ",
  [0x6B] = "ヒ",
  [0x6C] = "フ",
  [0x6D] = "ヘ",
  [0x6E] = "ホ",
  [0x6F] = "í",
  [0x70] = "ミ",
  [0x71] = "ム",
  [0x72] = "メ",
  [0x73] = "モ",
  [0x74] = "ヤ",
  [0x75] = "ユ",
  [0x76] = "ヨ",
  [0x77] = "ラ",
  [0x78] = "リ",
  [0x79] = "ル",
  [0x7A] = "レ",
  [0x7B] = "ロ",
  [0x7C] = "ワ",
  [0x7D] = "ヲ",
  [0x7E] = "ン",
  [0x7F] = "ァ",
  [0x80] = "ィ",
  [0x81] = "ゥ",
  [0x82] = "ェ",
  [0x83] = "ォ",
  [0x84] = "ャ",
  [0x85] = "<",
  [0x86] = ">",
  [0x87] = "ガ",
  [0x88] = "ギ",
  [0x89] = "グ",
  [0x8A] = "ゲ",
  [0x8B] = "ゴ",
  [0x8C] = "ザ",
  [0x8D] = "ジ",
  [0x8E] = "ズ",
  [0x8F] = "ゼ",
  [0x90] = "ゾ",
  [0x91] = "ダ",
  [0x92] = "ヂ",
  [0x93] = "ヅ",
  [0x94] = "デ",
  [0x95] = "ド",
  [0x96] = "バ",
  [0x97] = "ビ",
  [0x98] = "ブ",
  [0x99] = "ベ",
  [0x9A] = "ボ",
  [0x9B] = "パ",
  [0x9C] = "ピ",
  [0x9D] = "プ",
  [0x9E] = "ペ",
  [0x9F] = "ポ",
  [0xA0] = "ッ",
  [0xA1] = "0",
  [0xA2] = "1",
  [0xA3] = "2",
  [0xA4] = "3",
  [0xA5] = "4",
  [0xA6] = "5",
  [0xA7] = "6",
  [0xA8] = "7",
  [0xA9] = "8",
  [0xAA] = "9",
  [0xAB] = "!",
  [0xAC] = "?",
  [0xAD] = ".",
  [0xAE] = "-",
  [0xAF] = "·",
  [0xB0] = "…",
  [0xB1] = "“",
  [0xB2] = "”",
  [0xB3] = "‘",
  [0xB4] = "’",
  [0xB5] = "♂",
  [0xB6] = "♀",
  [0xB7] = "¥",
  [0xB8] = ",",
  [0xB9] = "×",
  [0xBA] = "/",
  [0xBB] = "A",
  [0xBC] = "B",
  [0xBD] = "C",
  [0xBE] = "D",
  [0xBF] = "E",
  [0xC0] = "F",
  [0xC1] = "G",
  [0xC2] = "H",
  [0xC3] = "I",
  [0xC4] = "J",
  [0xC5] = "K",
  [0xC6] = "L",
  [0xC7] = "M",
  [0xC8] = "N",
  [0xC9] = "O",
  [0xCA] = "P",
  [0xCB] = "Q",
  [0xCC] = "R",
  [0xCD] = "S",
  [0xCE] = "T",
  [0xCF] = "U",
  [0xD0] = "V",
  [0xD1] = "W",
  [0xD2] = "X",
  [0xD3] = "Y",
  [0xD4] = "Z",
  [0xD5] = "a",
  [0xD6] = "b",
  [0xD7] = "c",
  [0xD8] = "d",
  [0xD9] = "e",
  [0xDA] = "f",
  [0xDB] = "g",
  [0xDC] = "h",
  [0xDD] = "i",
  [0xDE] = "j",
  [0xDF] = "k",
  [0xE0] = "l",
  [0xE1] = "m",
  [0xE2] = "n",
  [0xE3] = "o",
  [0xE4] = "p",
  [0xE5] = "q",
  [0xE6] = "r",
  [0xE7] = "s",
  [0xE8] = "t",
  [0xE9] = "u",
  [0xEA] = "v",
  [0xEB] = "w",
  [0xEC] = "x",
  [0xED] = "y",
  [0xEE] = "z",
  [0xEF] = "▶",
  [0xF0] = ":",
  [0xF1] = "Ä",
  [0xF2] = "Ö",
  [0xF3] = "Ü",
  [0xF4] = "ä",
  [0xF5] = "ö",
  [0xF6] = "ü",
  [0xFF] = "$",
}

local Charmap = {}
Charmap.TERMINATOR = 0xFF
Charmap.BYTE_TO_CHAR = BYTE_TO_CHAR

-- Single-byte line-break control codes (charmap.txt: '\l'=scroll up window,
-- '\p'=new paragraph, '\n'=new line). All three render as a plain newline
-- here -- this project doesn't yet have a text window with a distinct
-- "scroll" vs. "paragraph" behavior, so the distinction is only meaningful
-- once one exists.
local LINEBREAK_BYTES = { [0xFA] = true, [0xFB] = true, [0xFE] = true }

-- 0xFD-prefixed codes are always exactly 2 bytes (FD + subcode), no
-- parameters -- runtime string-variable placeholders (charmap.txt).
local VAR_PLACEHOLDER_NAMES = {
  [0x01] = "PLAYER",
  [0x02] = "STR_VAR_1",
  [0x03] = "STR_VAR_2",
  [0x04] = "STR_VAR_3",
  [0x06] = "RIVAL",
}

local byte = string.byte

-- Decodes charmap-encoded bytes into a UTF-8 Lua string. Stops at the
-- terminator byte (0xFF) by default, matching how name tables are laid out
-- (real bytes, then 0xFF, then zero padding to the record's fixed stride).
--
-- Line-break codes (0xFA/0xFB/0xFE) become "\n". 0xFD+subcode
-- (string-variable placeholders, e.g. the player's name) become
-- "{PLAYER}"-style tags for known subcodes, "{FD:XX}" otherwise.
-- 0xFC+subcode (the extended control-code prefix -- colors, waits, fonts,
-- sound cues) becomes "{FC:XX}"; **only the 2-byte code itself is
-- consumed, not any trailing parameter bytes some FC subcodes take**
-- (e.g. COLOR takes 1 param byte, COLOR_HIGHLIGHT_SHADOW takes 3) -- text
-- after such a code will misdecode. Not yet fixed: doing it right needs a
-- per-subcode parameter-length table, deferred until real message text
-- using those specific codes needs decoding correctly.
-- Any other unmapped byte renders as a bracketed hex placeholder rather
-- than silently dropping data.
function Charmap.decode(data, stopAtTerminator)
  if stopAtTerminator == nil then stopAtTerminator = true end
  local out = {}
  local i = 1
  local n = #data
  while i <= n do
    local b = byte(data, i)
    if stopAtTerminator and b == Charmap.TERMINATOR then
      break
    end
    if LINEBREAK_BYTES[b] then
      out[#out + 1] = "\n"
      i = i + 1
    elseif b == 0xFD then
      local sub = byte(data, i + 1)
      out[#out + 1] = "{" .. (VAR_PLACEHOLDER_NAMES[sub] or ("FD:%02X"):format(sub or 0)) .. "}"
      i = i + 2
    elseif b == 0xFC then
      local sub = byte(data, i + 1)
      out[#out + 1] = ("{FC:%02X}"):format(sub or 0)
      i = i + 2
    else
      local ch = BYTE_TO_CHAR[b]
      out[#out + 1] = ch or ("[%02X]"):format(b)
      i = i + 1
    end
  end
  return table.concat(out)
end

-- Decodes one entry of a fixed-stride charmap string table (species names,
-- ability names, move names, etc. are all laid out this way: `stride` bytes
-- per entry, real text then a 0xFF terminator then zero padding).
function Charmap.decodeAt(data, tableOffset, stride, index)
  local start = tableOffset + index * stride
  local record = data:sub(start + 1, start + stride)
  if #record < stride then
    error(("charmap table read ran past end of data at index %d"):format(index))
  end
  return Charmap.decode(record)
end

return Charmap
