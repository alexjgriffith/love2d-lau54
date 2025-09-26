print(_VERSION)

function love.load (args)
   for key,value in pairs(args) do
      print (string.format("%s,%s",key,value))
   end
end
