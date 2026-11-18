-- Parser JSON autoral e independente. Retorna nil,erro em caso de entrada invalida.
local M={}
local function unicode(cp)
  if cp<0x80 then return string.char(cp)
  elseif cp<0x800 then return string.char(0xC0+math.floor(cp/64),0x80+cp%64)
  elseif cp<0x10000 then return string.char(0xE0+math.floor(cp/4096),0x80+math.floor(cp/64)%64,0x80+cp%64)
  elseif cp<=0x10FFFF then return string.char(0xF0+math.floor(cp/262144),0x80+math.floor(cp/4096)%64,0x80+math.floor(cp/64)%64,0x80+cp%64) end
  error('Unicode invalido')
end
function M.decode(src)
  if type(src)~='string' then return nil,'Esperado texto JSON' end
  local i,n=1,#src
  local function space()
    while i<=n and src:sub(i,i):match('[ \t\n\r]') do i=i+1 end
  end
  local function stringval()
    assert(src:sub(i,i)=='"','Aspas esperadas');i=i+1
    local out={}
    while i<=n do
      local ch=src:sub(i,i);i=i+1
      if ch=='"' then return table.concat(out) end
      if ch=='\\' then
        local e=src:sub(i,i);i=i+1
        local map={['"']='"',['\\']='\\',['/']='/',b='\b',f='\f',n='\n',r='\r',t='\t'}
        if map[e] then out[#out+1]=map[e]
        elseif e=='u' then
          local hex=src:sub(i,i+3)
          assert(hex:match('^%x%x%x%x$'),'Unicode invalido');i=i+4
          local cp=tonumber(hex,16)
          if cp>=0xD800 and cp<=0xDBFF then
            assert(src:sub(i,i+1)=='\\u','Par surrogate incompleto');i=i+2
            local h=src:sub(i,i+3)
            assert(h:match('^%x%x%x%x$'),'Par surrogate invalido');i=i+4
            local low=tonumber(h,16)
            assert(low>=0xDC00 and low<=0xDFFF,'Par surrogate invalido')
            cp=0x10000+(cp-0xD800)*1024+low-0xDC00
          else assert(cp<0xDC00 or cp>0xDFFF,'Surrogate isolado') end
          out[#out+1]=unicode(cp)
        else error('Escape invalido') end
      else
        assert(ch:byte()>=32,'Controle invalido')
        out[#out+1]=ch
      end
    end
    error('String nao fechada')
  end
  local value
  value=function(depth)
    assert(depth<48,'JSON muito profundo')
    space();local ch=src:sub(i,i)
    if ch=='"' then return stringval()
    elseif ch=='{' then
      i=i+1;space();local ob={}
      if src:sub(i,i)=='}' then i=i+1;return ob end
      while true do
        space();assert(src:sub(i,i)=='"','Chave invalida')
        local k=stringval();space();assert(src:sub(i,i)==':','Dois pontos esperados')
        i=i+1;ob[k]=value(depth+1);space()
        local sep=src:sub(i,i);i=i+1
        if sep=='}' then return ob end
        assert(sep==',','Virgula esperada')
      end
    elseif ch=='[' then
      i=i+1;space();local arr={}
      if src:sub(i,i)==']' then i=i+1;return arr end
      while true do
        arr[#arr+1]=value(depth+1);space()
        local sep=src:sub(i,i);i=i+1
        if sep==']' then return arr end
        assert(sep==',','Virgula esperada')
      end
    elseif src:sub(i,i+3)=='true' then i=i+4;return true
    elseif src:sub(i,i+4)=='false' then i=i+5;return false
    elseif src:sub(i,i+3)=='null' then i=i+4;return M.null
    else
      local remain=src:sub(i)
      local num=remain:match('^%-?%d+%.%d+[eE][+-]?%d+')
        or remain:match('^%-?%d+[eE][+-]?%d+')
        or remain:match('^%-?%d+%.%d+')
        or remain:match('^%-?%d+')
      assert(num and #num>0,'Valor invalido')
      assert(not num:match('^%-?0%d'),'Zero inicial invalido')
      local following=remain:sub(#num+1,#num+1)
      assert(following=='' or following:match('[,%]%}%s]'),'Numero invalido')
      local v=tonumber(num);assert(v and v==v,'Numero invalido')
      i=i+#num;return v
    end
  end
  local ok,result=pcall(function()
    local parsed=value(0);space();assert(i>n,'Dados apos JSON')
    return parsed
  end)
  if not ok then return nil,result end
  return result
end
M.null={}
return M
