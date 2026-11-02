local rows = {
 {{19,".::."}},
 {{17,"...;;..."}},
 {{11,"...................."}},
 {{6,".';:;...',;::cccc::;,'...,:;'."}},
 {{3,".,cc:;'..;cc:'.......';cc:'.';:cc,."}},
 {{0,".,cc:,....;cc;."},{16,".........."},{28,"'cc:....,:cc,."}},
 {{0,"cc'. ....,cc' ...':cccc:' .. .cc:......'cc"}},
 {{0,"c."},{4,".....:cc."},{14,"...cccccccc'"},{27,".."},{30,":cc'...."},{40,".c"}},
 {{0,"cc,......;cc. ...,cccccc,... .ccc......,cc"}},
 {{0,".':cc;,...;cc'"},{16,"..........."},{28,".:c:...';cc:'."}},
 {{1,"."},{4,".,:c:;.':cc;..."},{23,"...,:c:.,;:cc,."},{40,".."}},
 {{0,";:;"},{7,".''....';:cc'"},{22,".ccc;,....''."},{39,",::"}},
 {{11,".....,cc,..'cc:....."}},
 {{16,",cc,...cc:."}},
 {{6,".::'"},{16,",cc."},{23,"ccc"},{32,".::."}},
 {{7,".;cc:;,,;cc,"},{23,"':c:,,,;cc'"}},
 {{10,".,:cc'"},{25,".;cc:;'."}},
}
for _, r in ipairs(rows) do
  local line = {}
  for _, seg in ipairs(r) do
    for i = 1, #seg[2] do line[seg[1] + i] = seg[2]:sub(i, i) end
  end
  local n = 0; for k in pairs(line) do if k > n then n = k end end
  local out, cur = {}, nil
  for i = 1, n do
    local ch = line[i] or " "
    local want = ch:match("%a") and "$1" or (ch ~= " " and "$2" or cur)
    if want ~= cur then out[#out + 1] = want; cur = want end
    out[#out + 1] = ch
  end
  print(table.concat(out))
end
