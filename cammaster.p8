pico-8 cartridge // http://www.pico-8.com
version 14
__lua__
-- ~cammaster~
-- some code based on celeste by matt thorson + noel berry

-- todo:
-- - restrict the use of powers when valid (not on screen transition, etc.)

-- level ideas:
-- - using jump buffer from room transition
-- - using jump buffer from cam freeze disabling

-- globals --
-------------

room = {x=0, y=0, tw=0, th=0}
previous_room = {x=0, y=0, tw=0, th=0}
room_trans = false
player_spawn = {x=0, y=0, spd_x=0, spd_y=0, flip_x=false}
cur_cam = {x=0, y=0}
fr_cam = {x=0, y=0}

state = state_normal
state_timeout = 0
state_params = {}

pow_none = -1
pow_off = 0
pow_on = 1
powers = {shot = pow_on, free_cam = pow_off, freeze_cam = pow_off, wrap_cam = pow_off}
power_slots = 4

objects = {}
types = {}

menu = {cursor=0,prev_right=false,prev_left=false,prev_swap=false,prev_ok=false}

shake=0
sfx_timer=0
flash_bg=false
max_charge = 30

-- constants --
---------------

k_left=0
k_right=1
k_up=2
k_down=3
k_jump=4
k_special=5

flag_solid = 0x01
flag_terrain = 0x02
flag_bg = 0x04
flag_fg = 0x08

state_normal = 0
state_params[state_normal] = {timeout = 0, frozen = false, cam_move = false}

state_free_cam_in = 1
state_params[state_free_cam_in] = {timeout = 20, frozen = true, cam_move = true}

state_free_cam_out = 2
state_params[state_free_cam_out] = {timeout = 20, frozen = true, cam_move = true}

state_freeze_cam_in = 3
state_params[state_freeze_cam_in] = {timeout = 20, frozen = true, cam_move = false}

state_freeze_cam_out = 4
state_params[state_freeze_cam_out] = {timeout = 20, frozen = true, cam_move = true}

state_wrap_cam_in = 7
state_params[state_wrap_cam_in] = {timeout = 20, frozen = true, cam_move = false}

state_wrap_cam_out = 8
state_params[state_wrap_cam_out] = {timeout = 20, frozen = true, cam_move = true}

state_room_transition = 5
state_params[state_room_transition] = {timeout = 20, frozen = true, cam_move = true}

state_dying = 6
state_params[state_dying] = {timeout = 30, frozen = false, cam_move = false}

state_menu = 9
state_params[state_menu] = {timeout = 0, frozen = true, cam_move = false}

-- entry point --
-----------------

function _init()
 begin_game()
end

function begin_game()
-- frames=0
-- seconds=0
-- minutes=0
-- start_game=false
 player_spawn = {x=216, y=24, spd_x=0, spd_y=0, flip_x=false}
 load_room(0,0)
end

psfx=function(num)
 if sfx_timer<=0 then
  sfx(num)
 end
end

function kill_player(obj)
 sfx_timer=12
 sfx(0)
-- deaths+=1
 shake=10

 -- freeze cam on player
 fr_cam.x = cur_cam.x
 fr_cam.y = cur_cam.y

 state = state_dying
 state_timeout = state_params[state].timeout

 destroy_object(obj)

 -- after a death, reset spawn speed
 player_spawn.spd_x = 0
 player_spawn.spd_y = 0

 for dir=0,7 do
  local angle=(dir/8)
  part = init_object(dead_particle,obj.x+4,obj.y+4)
  part.spd.x = sin(angle)*1.5
  part.spd.y = cos(angle)*1.5
 end
end

smoke={
 init=function(this)
  this.spr=29
  this.spd.y=-0.1
  this.spd.x=0.3+rnd(0.2)
  this.x+=-1+rnd(2)
  this.y+=-1+rnd(2)
  this.flip.x=maybe()
  this.flip.y=maybe()
  this.solids=false
 end,
 update=function(this)
  this.spr+=0.2
  if this.spr>=32 then
   destroy_object(this)
  end
 end
}

shot={
 init=function(this)
  this.hitbox = {x=1,y=2,w=5,h=5}
  this.spr=10
  this.solids=true
 end,

 update=function(this)
  -- check collision
  if this.spr == 10 then
   if this.bonk then
    this.spr = 11
    this.spd.x = 0
    this.spd.y = 0
   end
  else
   this.spr += 0.5
   if this.spr >= 15 then
    destroy_object(this)
   end
  end
 end
}

upspike={
 tile=27,
 init=function(this)
  this.hitbox = {x=0,y=0,w=8,h=3}
  this.solid=false
 end,

 update=function(this)
  -- check collision with player
  p = this.collide(player, 0, 0)
  if p ~= nil and p.spd.y <= 0 then
   kill_player(p)
  end
 end
}
add(types,upspike)

downspike={
 tile=17,
 init=function(this)
  this.hitbox = {x=0,y=5,w=8,h=3}
  this.solid=false
 end,

 update=function(this)
  -- check collision with player
  p = this.collide(player, 0, 0)
  if p ~= nil and p.spd.y >= 0 then
   kill_player(p)
  end
 end
}
add(types,downspike)

rightspike={
 tile=43,
 init=function(this)
  this.hitbox = {x=0,y=0,w=3,h=8}
  this.solid=false
 end,

 update=function(this)
  -- check collision with player
  p = this.collide(player, 0, 0)
  if p ~= nil and p.spd.x <= 0 then
   kill_player(p)
  end
 end
}
add(types,rightspike)

leftspike={
 tile=59,
 init=function(this)
  this.hitbox = {x=5,y=0,w=3,h=8}
  this.solid=false
 end,

 update=function(this)
  -- check collision with player
  p = this.collide(player, 0, 0)
  if p ~= nil and p.spd.x >= 0 then
   kill_player(p)
  end
 end
}
add(types,leftspike)

dead_particle={
 init=function(this)
  this.solids=false
  this.collideable=false
  this.t=10
 end,

 update=function(this)
  this.x += this.spd.x
  this.y += this.spd.y
  this.t -= 1
  if this.t <= 0 then
   destroy_object(this)
  end
 end,

 draw=function(this)
  rectfill(this.x-this.t/5,this.y-this.t/5,this.x+this.t/5,this.y+this.t/5,14+this.t%2)
 end
}

bridge={
 tile=26,
 init=function(this)
  this.hitbox = {x=0,y=0,w=8,h=2}
  this.solid=false
 end
}
add(types,bridge)

holed_bridge={
 tile=25,
 init=function(this)
  this.hitbox = {x=0,y=0,w=8,h=2}
  this.solid=false
 end
}
add(types,holed_bridge)

door={
 tile=63,
 init=function(this)
  this.solids=false

  -- compute next room
  this.room={tx=-1,ty=-1}
  this.player={x=0,y=0}

  if (this.x == 0) then
   this.room = {tx=room.tx-16,ty=room.ty+flr(this.y/128)}
   this.hitbox = {x=0,y=0,w=3,h=8}
   this.player = {x=116,y=this.y%128}
  end
  if (this.x%128 == 120) then
   this.room = {tx=room.tx+room.tw,ty=room.ty+flr(this.y/128)}
   this.hitbox = {x=6,y=0,w=3,h=8}
   this.player = {x=4,y=this.y%128}
  end
  if (this.y == 0) then
   this.room = {tx=room.tx+flr(this.x/128),ty=room.ty-1}
   this.hitbox = {x=0,y=0,w=8,h=3}
   this.player = {x=this.x%128,y=116}
  end
  if (this.y%128 == 120) then
   this.room = {tx=room.tx+flr(this.x/128),ty=room.ty+room.th}
   this.hitbox = {x=0,y=6,w=8,h=3}
   this.player = {x=this.x%128,y=4}
  end

  full_room = {tx=this.room.tx,ty=this.room.ty}
 -- full_room = this.room
  guess_room_bounds(full_room)
  this.player.x += 8*(this.room.tx-full_room.tx)
  this.player.y += 8*(this.room.ty-full_room.ty)
  this.room = full_room
 end,

 update=function(this)
  if (this.room.tx == -1) then
   return
  end

  -- only enable door when no power is enabled
  if powers.free_cam ~= pow_on and powers.freeze_cam ~= pow_on and powers.wrap_cam ~= pow_on then
   -- check collision with player
   p = this.collide(player,0,0)
   if p then
    -- save new player spawn
    player_spawn.x = this.player.x
    player_spawn.y = this.player.y
    player_spawn.spd_x = p.spd.x
    player_spawn.spd_y = p.spd.y
    player_spawn.flip_x = p.flip.x

    -- save camera
    fr_cam.x = cur_cam.x
    fr_cam.y = cur_cam.y

    fr_cam.x += 8*(room.tx - this.room.tx)
    fr_cam.y += 8*(room.ty - this.room.ty)

    -- room transition
    previous_room.tx = room.tx
    previous_room.ty = room.ty
    previous_room.tw = room.tw
    previous_room.th = room.th

    -- load room and player
    load_room(this.room.tx,this.room.ty)

    state = state_room_transition
    state_timeout = state_params[state].timeout

   end
  end
 end,

 draw=function(this)
  if powers.free_cam ~= pow_on and powers.freeze_cam ~= pow_on and powers.wrap_cam ~= pow_on then
   spr(this.spr,this.x,this.y,1,1,this.flip.x,this.flip.y)
  end

--  print(this.room.tx,0,0,7)
--  print(this.room.ty,0,16,7)
--  print(this.player.x,0,35,7)
--  print(this.player.y,0,48,7)
 end
}
add(types,door)

textbox={
 tile=114,
 init=function(this)
  this.solids=false
  this.chars={82, 83, 83} -- TODO
  this.hitbox = {x=2,y=7,w=4,h=1}
  this.do_draw = 0
  this.timeout = 0
  this.player = {x=0,y=0}
 end,

 update=function(this)
   -- check collision with player
   p = this.collide(player,0,0)
   if p then
    if this.do_draw == 0 then
     this.timeout = 10
    end
    this.do_draw = 100
   else

   if this.do_draw == 1 then
    this.timeout = 10
   end

   if this.do_draw > 0 then
    this.do_draw -= 1
   end
end
   if this.timeout > 0 then
    this.timeout -= 1
   end

 end,

 draw=function(this)
  if this.do_draw == 0 and this.timeout == 0 then
   return
  end

  foreach(objects, function(o)
   if o.type == player then
       this.player.x = o.x
       this.player.y = o.y
   end
  end)

  local pos_x = this.player.x + 3 - (#this.chars*8/2)
  local pos_y = this.player.y - 12

  local fade = this.timeout
  if this.do_draw == 0 and this.timeout ~= 0 then fade = 9 - fade end

  if fade > 6 then
   fillp(0b0111110110111110.1)
  elseif fade > 3 then
   fillp(0b1010100101010011.1)
  elseif fade > 0 then
   fillp(0b0010010000011000.1)
  end

   circ(pos_x + 4, pos_y + 4, 4, 7)
   rect(pos_x + 4, pos_y, pos_x + #this.chars*8 - 4, pos_y + 8, 7)
   circ(pos_x + #this.chars*8 - 4, pos_y + 4, 4, 7)
   circfill(pos_x + 4, pos_y + 4, 3, 1)
   rectfill(pos_x + 4, pos_y + 1, pos_x + #this.chars*8 - 4, pos_y + 7, 1)
   circfill(pos_x + #this.chars*8 - 4, pos_y + 4, 3, 1)

  fillp()

  if this.do_draw > 0 and this.timeout == 0 then
   for s=1,#this.chars do
    spr(this.chars[s], pos_x+(s-1)*8, pos_y+1, 1, 1, false, false)
   end
  end
 end
}

add(types,upgrade)

upgrade={
 tile=101,
 init=function(this)
  this.solids=false
  this.spr_index=0

  this.hitbox = {x=0,y=0,w=8,h=8}
 end,

 update=function(this)
   -- check collision with player
   p = this.collide(player,0,0)
   if p then
       state = state_menu
       state_timeout = state_params[state].timeout
   end

   this.spr = this.type.tile + flr(this.spr_index/16) * flr((this.spr_index-16)/4)
   this.spr_index += 1
   if this.spr_index > 31 then
    this.spr_index = 0
   end
 end
}

add(types,upgrade)

-->8
-- player entity --
-------------------

ps_normal = 0
ps_recoil = 1
ps_fall = 2

player =
{
 tile=1,
 init=function(this)
  this.jgrace=0
  this.jbuffer=0
  this.charge_time=0
  this.state = ps_normal
  this.hitbox = {x=1,y=1,w=6,h=7}
  this.spr_off=0
  this.charge_spr=0
  -- why the autorepeat on btnp...
  this.prev_jump=false
  this.prev_special=false
  this.special_timeout=0
  this.last_smoke_x=0
 end,

 update=function(this)

  local h_input = btn(k_right) and 1 or (btn(k_left) and -1 or 0)

  if this.special_timeout > 0 then
   this.special_timeout -= 1
  end

  -- wrap coordinates
  if powers.wrap_cam == pow_on then
   if this.x < fr_cam.x then
    this.x += 128
   elseif this.x > fr_cam.x + 128 then
    this.x -= 128
   end
   if this.y < fr_cam.y then
    this.y += 128
   elseif this.y > fr_cam.y + 128 then
    this.y -= 128
   end
  end

  -- oob collide
  if this.x < -60
   or this.x > room.tw*8+60
   or this.y < -60
   or this.y > room.th*8+60 then
   kill_player(this)
  end

  local on_ground = this.is_solid(0,1)

  if this.state == ps_normal then
   -- no recoil

   local jump = btn(k_jump) and not this.prev_jump

   -- jump buffer
   if jump then
    this.jbuffer=8
   elseif this.jbuffer>0 then
    this.jbuffer-=1
   end
   this.prev_jump = btn(k_jump)

   -- jump grace time
   if on_ground ~= 0 then
    this.jgrace=4
   elseif this.jgrace > 0 then
    this.jgrace-=1
   end

   -- jump
   if this.jbuffer>0 then
    if this.jgrace>0 then
     psfx(1)
     this.jbuffer=0
     this.jgrace=0
     -- down+jump on holed bridge
     if on_ground == 2 and btn(k_down) then
      this.y+=1
      on_ground = 0
     else
      this.spd.y=-2
     end
    end
   end

   -- jump release
   if this.spd.y<0 and not btn(k_jump) then
    this.spd.y=0
   end

   -- move
   local maxrun=0.8
   local accel=0.3
   local deccel=0.1

   if on_ground ~= 0 then
    -- Add friction on the ground
    deccel = abs(this.spd.x)/10
   else
    accel=0.2
   end

   if abs(this.spd.x) > maxrun then
    this.spd.x=appr(this.spd.x,sign(this.spd.x)*maxrun,deccel)
    -- add smoke effect
    if on_ground ~= 0 then
     if abs(this.last_smoke_x - this.x) > 12 then
      init_object(smoke,this.x,this.y + 6)
      this.last_smoke_x = this.x
     end
    end
   else
    this.spd.x=appr(this.spd.x,h_input*maxrun,accel)
   end

   -- facing
   if btn(k_right) or btn(k_left) then
    this.flip.x=btn(k_left)
   end

   -- gravity
   local maxfall=2.5
   local gravity=0.1

   if abs(this.spd.y) <= 0.15 then
    gravity*=0.5
   end

   if on_ground == 0 then
    this.spd.y=appr(this.spd.y,maxfall,gravity)
   end

   -- special inputs

   local special = btn(k_special)

   -- recoil

   if powers.shot == pow_on then
   if special then
    this.charge_time += 1
   elseif this.charge_time < max_charge then
    this.charge_time = 0
   else
    -- create shot
    shotobj = init_object(shot,this.x,this.y)
    shotobj.flip.x = this.flip.x
    local s_full = 8
    local s_half = s_full * 0.70710678118

    -- start recoil
    this.state = ps_recoil

    local r_full = 8
    local r_half = r_full * 0.70710678118

    local v_input=(btn(k_up) and -1 or (btn(k_down) and 1 or 0))

    local dir_pressed = abs(h_input) + abs(v_input)

    if dir_pressed == 2 then
     -- diagonal movement
     this.spd.x=-h_input*r_half
     this.spd.y=-v_input*r_half
     shotobj.spd.x = h_input*s_half
     shotobj.spd.y = v_input*s_half
    elseif dir_pressed == 1 then
     -- hor/vert movement
     this.spd.x=-h_input*r_full
     this.spd.y=-v_input*r_full
     shotobj.spd.x = h_input*s_full
     shotobj.spd.y = v_input*s_full
    else
     -- no movement
     this.spd.x=this.flip.x and r_full or -r_full
     this.spd.y=0
     shotobj.spd.x = this.flip.x and -s_full or s_full
     shotobj.spd.y = 0
    end

    this.charge_time = 0
   end
   end

   -- free camera
   if powers.free_cam ~= pow_none and on_ground ~= 0 and special and not this.prev_special and btn(k_down) and not btn(k_up) and this.special_timeout > 0 and
   -- not when out of bound
      this.x+this.hitbox.x >= 0 and this.x+this.hitbox.x+this.hitbox.w < (room.tw*8) and
      this.y+this.hitbox.y >= 0 and this.y+this.hitbox.y+this.hitbox.h < (room.th*8) and
   -- not when freeze or wrap cam active
      powers.freeze_cam ~= pow_on and powers.wrap_cam ~= pow_on then
    powers.free_cam = 1 - powers.free_cam
    if powers.free_cam == pow_on then
     state = state_free_cam_in
    else
     state = state_free_cam_out
    end
    state_timeout = state_params[state].timeout
    fr_cam.x = cur_cam.x
    fr_cam.y = cur_cam.y
   end

   -- freeze camera
   if powers.freeze_cam ~= pow_none and on_ground ~= 0 and special and not this.prev_special and btn(k_up) and not btn(k_down) and this.special_timeout > 0 and powers.wrap_cam ~= pow_on then
    powers.freeze_cam = 1 - powers.freeze_cam
    if powers.freeze_cam  == pow_on then
     state = state_freeze_cam_in
     fr_cam.x = cur_cam.x
     fr_cam.y = cur_cam.y
    else
     state = state_freeze_cam_out
    end
    state_timeout = state_params[state].timeout
--    this.charge_time = 0
   end

   -- wrap camera
   if powers.wrap_cam ~= pow_none and on_ground ~= 0 and special and not this.prev_special and not btn(k_up) and not btn(k_down) and this.special_timeout > 0 and powers.freeze_cam ~= pow_on then
    powers.wrap_cam = 1 - powers.wrap_cam
    if powers.wrap_cam == pow_on then
     state = state_wrap_cam_in
     fr_cam.x = cur_cam.x
     fr_cam.y = cur_cam.y
    else
     state = state_wrap_cam_out
    end
    state_timeout = state_params[state].timeout
--    this.charge_time = 0
   end

   -- udpate special state
   if special and not this.prev_special then
    this.special_timeout = 15
   end
   this.prev_special = btn(k_special)

  elseif this.state == ps_recoil then
   if this.bonk then
    -- player collide
    this.spd.x = 0
    this.spd.y = 0
    this.state = ps_fall
    shake=6
    psfx(3)
--    freeze=2
    init_object(smoke,this.x,this.y)

    -- disable cam_freeze
    if powers.freeze_cam == pow_on then
     powers.freeze_cam = pow_off
     state = state_freeze_cam_out
     state_timeout = state_params[state].timeout
--     cam_timer = 9
--     cam_focus_timer = cam_focus_spd
    end
   end
  else -- this.state == ps_fall

   if on_ground ~= 0 then
    -- end recoil
    this.state = ps_normal
   else
    -- only apply gravity
    local maxfall=2.5
    local gravity=0.25

    this.spd.y=appr(this.spd.y,maxfall,gravity)
   end
  end

  -- animation
  this.spr_off+=0.25
  if this.state == ps_recoil then
   this.spr = 8
elseif this.state == ps_fall then
   this.spr = 9
elseif on_ground == 0 then
   if this.is_solid(h_input,0) ~= 0 then
    this.spr=5
   else
    this.spr=3
   end
  elseif btn(k_down) then
   this.spr=6
  elseif btn(k_up) then
   this.spr=7
  elseif (this.spd.x==0) or (not btn(k_left) and not btn(k_right)) then
   this.spr=1
  else
   this.spr=1+this.spr_off%4
  end

  -- charge animation
  --if this.charge_time > 0 then
  -- this.charge_spr = 8+(this.charge_time/4)%4
  -- this.charge_x = this.flip.x and (this.x-8) or (this.x+8)
  --else
  -- this.charge_spr = 0
  --end

 end, --<end update loop

 draw=function(this)

  if this.charge_time > max_charge then
   if flr(this.charge_time/2)%2 == 0 then
    pal(6,12)
    pal(8,14)
    pal(2,8)
    --pal(9,10)
    --pal(4,15)
    --pal(11,13)
    --pal(3,1)
   else
    --pal(6,12)
    --pal(7,12)
   end
  elseif this.charge_time > 0 then
   if flr(this.charge_time/6)%2 == 0 then
    pal(6,12)
   end
  end

  spr(this.spr,this.x,this.y,1,1,this.flip.x,this.flip.y)

  -- draw additional sprites when cam wrapping
  if powers.wrap_cam == pow_on then
   if this.x > fr_cam.x + 120 then
    spr(this.spr,this.x-128,this.y,1,1,this.flip.x,this.flip.y)
   end
   if this.y > fr_cam.y + 120 then
    spr(this.spr,this.x,this.y-128,1,1,this.flip.x,this.flip.y)
   end
   if (this.x > fr_cam.x + 120) and (this.y > fr_cam.y + 120) then
    spr(this.spr,this.x-128,this.y-128,1,1,this.flip.x,this.flip.y)
   end
  end

  pal()

  -- cam freeze

  if state == state_freeze_cam_in then
   if state_timeout > 8 or state_timeout < 2 then
    spr(18,this.x,this.y-6,1,1)
   elseif state_timeout > 7 or state_timeout < 3 then
    spr(19,this.x,this.y-6,1,1)
   else
    spr(20,this.x,this.y-6,1,1)
   end
  end

  -- charge animation
  --if this.charge_spr > 0 then
  -- spr(this.charge_spr,this.charge_x,this.y,1,1,this.flip.x,this.flip.y)
  --end

 end
}

add(types,player)
-->8
-- object functions --
-----------------------

function init_object(type,x,y)
 local obj = {}
 obj.type = type
 obj.collideable=true
 obj.solids=true
 obj.bonk=false

 obj.spr = type.tile
 obj.flip = {x=false,y=false}

 obj.x = x
 obj.y = y
 obj.hitbox = { x=0,y=0,w=8,h=8 }

 obj.spd = {x=0,y=0}
 obj.rem = {x=0,y=0}

 obj.is_solid=function(ox,oy)
  -- check solid tiles
  if solid_at(obj.x+obj.hitbox.x+ox,obj.y+obj.hitbox.y+oy,obj.hitbox.w,obj.hitbox.h) then
   return 1
  end

  -- check room bounds
  if powers.free_cam ~= pow_on and powers.wrap_cam ~= pow_on then
   if obj.x+obj.hitbox.x+ox < 0
   or obj.x+obj.hitbox.x+obj.hitbox.w+ox >= (room.tw*8)
   or obj.y+obj.hitbox.y+oy < 0
   or obj.y+obj.hitbox.y+obj.hitbox.h+oy >= (room.th*8) then
    -- disable room bounds collision if at a door transition
    if not obj.collide(door,ox,oy) then
     return 1
    end
   end
  end

  -- check cam bounds
  if powers.freeze_cam == pow_on then
   if obj.x+obj.hitbox.x+ox < fr_cam.x+4
   or obj.x+obj.hitbox.x+obj.hitbox.w+ox > fr_cam.x+124
   or obj.y+obj.hitbox.y+oy < fr_cam.y+4
   or obj.y+obj.hitbox.y+obj.hitbox.h+oy > fr_cam.y+124 then
    return 1
   end
  end

  -- check bridge
  if oy == 1 and not obj.collide(bridge,0,0) and obj.collide(bridge,0,1) then
   return 1
  end

  -- check holed bridge
  if oy == 1 and not obj.collide(holed_bridge,0,0) and obj.collide(holed_bridge,0,1) then
   return 2
  end

  return 0
--   or obj.check(fall_floor,ox,oy)
--   or obj.check(fake_wall,ox,oy)
 end

 obj.collide=function(type,ox,oy)
  local other
  for i=1,count(objects) do
   other=objects[i]
   if other ~=nil and other.type == type and other != obj and other.collideable and
    other.x+other.hitbox.x+other.hitbox.w > obj.x+obj.hitbox.x+ox and
    other.y+other.hitbox.y+other.hitbox.h > obj.y+obj.hitbox.y+oy and
    other.x+other.hitbox.x < obj.x+obj.hitbox.x+obj.hitbox.w+ox and
    other.y+other.hitbox.y < obj.y+obj.hitbox.y+obj.hitbox.h+oy then
    return other
   end
  end
  return nil
 end

 obj.check=function(type,ox,oy)
  return obj.collide(type,ox,oy) ~=nil
 end

 obj.move=function(ox,oy)
  obj.bonk = false

  local amount
  -- [x] get move amount
  obj.rem.x += ox
  amount = flr(obj.rem.x + 0.5)
  obj.rem.x -= amount
  obj.move_x(amount)

  -- [y] get move amount
  obj.rem.y += oy
  amount = flr(obj.rem.y + 0.5)
  obj.rem.y -= amount
  obj.move_y(amount)
 end

 obj.move_x=function(amount)
  if obj.solids then
   local step = sign(amount)
   for i=0,(abs(amount)-1) do
    if obj.is_solid(step,0) == 0 then
     obj.x += step
    else
     obj.spd.x = 0
     obj.rem.x = 0
     obj.bonk = true
     break
    end
   end
  else
   obj.x += amount
  end
 end

 obj.move_y=function(amount)
  if obj.solids then
   local step = sign(amount)
   for i=0,(abs(amount)-1) do
    if obj.is_solid(0,step) == 0 then
     obj.y += step
    else
     obj.spd.y = 0
     obj.rem.y = 0
     obj.bonk = true
     break
    end
   end
  else
   obj.y += amount
  end
 end

 add(objects,obj)
 if obj.type.init~=nil then
  obj.type.init(obj)
 end
 return obj
end

function destroy_object(obj)
 del(objects,obj)
end

-->8
-- room functions --
--------------------

-- guess the room bounds from the layout
function guess_room_bounds(r)
 r.tw = 16
 r.th = 16

 local new_tx = r.tx
 local new_ty = r.ty
 local new_tw = r.tw
 local new_th = r.th

 local rescan=true

 while rescan do
  rescan = false

  -- check left bound
  if r.tx>0 then
   for ty=r.ty,r.ty+r.th-1 do
    tile = mget(r.tx,ty)
    if not fget(tile,0) and tile!=63 then
     new_tx -= 16
     new_tw += 16
     rescan = true
     break
    end
   end
  end

  -- check right bound
  if (r.tx+r.tw)<112 then
   for ty=r.ty,r.ty+r.th-1 do
    tile = mget(r.tx+r.tw-1,ty)
    if not fget(tile,0) and tile!=63 then
     new_tw += 16
     rescan = true
     break
    end
   end
  end

  -- check top bound
  if r.ty>0 then
   for tx=r.tx,r.tx+r.tw-1 do
    tile=mget(tx,r.ty)
    if not fget(tile,0) and tile!=63 then
     new_ty -= 16
     new_th += 16
     rescan = true
     break
    end
   end
  end

  -- check bottom bound
  if (r.ty+r.th)<112 then
   for tx=r.tx,r.tx+r.tw-1 do
    tile=mget(tx,r.ty+r.th-1)
    if not fget(tile,0) and tile!=63 then
     new_th += 16
     rescan = true
     break
    end
   end
  end

  r.tx = new_tx
  r.ty = new_ty
  r.tw = new_tw
  r.th = new_th
 end
end

function load_room(tx,ty)
 powers.free_cam = min(powers.free_cam, pow_off)
 powers.freeze_cam = min(powers.freeze_cam, pow_off)
 powers.wrap_cam = min(powers.wrap_cam, pow_off)
 state = state_normal

 -- remove existing objects
 foreach(objects,destroy_object)

 -- guess room bounds
 room.tx = tx
 room.ty = ty
 guess_room_bounds(room)

 -- entities
 for tx=0,room.tw-1 do
  for ty=0,room.th-1 do
   local tile = mget(room.tx+tx,room.ty+ty)
   foreach(types,
   function(type)
    if type.tile == tile then
     init_object(type,tx*8,ty*8)
    end
   end)
  end
 end

 -- player
 p = init_object(player,player_spawn.x,player_spawn.y)
 p.spd.x = player_spawn.spd_x
 p.spd.y = player_spawn.spd_y
 p.flip.x = player_spawn.flip_x

end

-->8
-- update function --
-----------------------

function _update60()

 if sfx_timer>0 then
  sfx_timer-=1
 end

 -- update state timeout
 if state_timeout > 0 then
  state_timeout -= 1
  if state_timeout <= 0 then

   -- do some stuff based on the state we left
   if state == state_dying then
    load_room(room.tx,room.ty)
    return
   end

   state = state_normal
  end
 end

 if state == state_menu then
  update_menu()
  return
 end


 -- don't update objects is in a frozen state
 if state_params[state].frozen then
  return
 end

 -- update each object
 foreach(objects,function(obj)
  obj.move(obj.spd.x,obj.spd.y)
  if obj.type.update~=nil then
   obj.type.update(obj)
  end
 end)

 -- compute player camera
 foreach(objects, function(o)
  if o.type == player then
   if powers.freeze_cam == pow_on or powers.wrap_cam == pow_on then
    cur_cam.x = fr_cam.x
    cur_cam.y = fr_cam.y
   elseif powers.free_cam == pow_on then
    cur_cam.x = clamp(o.x-64,-64,room.tw*8-64)
    cur_cam.y = clamp(o.y-64,-64,room.th*8-64)
   else
    cur_cam.x = clamp(o.x-64,0,room.tw*8-128)
    cur_cam.y = clamp(o.y-64,0,room.th*8-128)
   end
  end
 end)

end

function update_menu()

 local right = btn(k_right) and not menu.prev_right
 local left = btn(k_left) and not menu.prev_left
 local swap = btn(k_jump) and not menu.prev_swap
 local ok = btn(k_special) and not menu.prev_ok

 if right and (menu.cursor < power_slots - 1) then
  menu.cursor += 1
 end

 if left and (menu.cursor > 0) then
  menu.cursor -= 1
 end

 menu.prev_right = btn(k_right)
 menu.prev_left = btn(k_left)
 menu.prev_swap = btn(k_jump)
 menu.prev_ok = btn(k_special)

end

-->8
-- drawing functions --
-----------------------
function _draw()
 -- reset all palette values and camera
 pal()
 camera()

 -- clear screen
 local bg_col = 0
 if flash_bg then
  bg_col = frames/5
 elseif new_bg~=nil then
  bg_col=2
 end
 rectfill(0,0,room.tw*8,room.th*8,bg_col)

 -- screenshake
 local shake_x = 0
 local shake_y = 0
 if shake>0 then
  shake-=1
  shake_x = -2+rnd(5)
  shake_y = -2+rnd(5)
 end

 -- set camera
 if powers.freeze_cam == pow_on or powers.wrap_cam == pow_on or state == state_dying then
  camera(shake_x+fr_cam.x,shake_y+fr_cam.y)
 else
  if state_params[state].cam_move then
   local q = 1 - state_timeout/state_params[state].timeout
   -- set the camera between the previous cam freeze and current cam
   camera(shake_x+interp_sin(fr_cam.x,cur_cam.x,q),
          shake_y+interp_sin(fr_cam.y,cur_cam.y,q))
  else
   camera(shake_x+cur_cam.x,
          shake_y+cur_cam.y)
  end
 end

 -- draw bg terrain
 map(room.tx,room.ty,0,0,room.tw,room.th,flag_bg)
 if state == state_room_transition then
  map(previous_room.tx,previous_room.ty,8*(previous_room.tx-room.tx),8*(previous_room.ty-room.ty),previous_room.tw,previous_room.th,flag_bg)
 end

 -- draw terrain
 map(room.tx,room.ty,0,0,room.tw,room.th,flag_terrain)
 if state == state_room_transition then
  map(previous_room.tx,previous_room.ty,8*(previous_room.tx-room.tx),8*(previous_room.ty-room.ty),previous_room.tw,previous_room.th,flag_terrain)
 end

 -- draw objects
 foreach(objects, function(o)
  draw_object(o)
 end)

 -- draw fg terrain
 map(room.tx,room.ty,0,0,room.tw,room.th,flag_fg)
 if state == state_room_transition then
  map(previous_room.tx,previous_room.ty,8*(previous_room.tx-room.tx),8*(previous_room.ty-room.ty),previous_room.tw,previous_room.th,flag_fg)
 end

 -- draw oob wall
 if state ~= state_room_transition then
  rectfill(-64,-64,-60,room.th*8+64,8)
  rectfill(-64,-64,room.tw*8+64,-60,8)
  rectfill(-64,room.th*8+60,room.tw*8+64,room.th*8+64,8)
  rectfill(room.tw*8+60,-60,room.tw*8+64,room.th*8+64,8)
 end

 -- reset camera
 camera()

 -- draw cam walls fade in
 if state == state_freeze_cam_in then
  if state_timeout > 6 then
   fillp(0b0111110110111110.1)
  elseif state_timeout > 3 then
   fillp(0b1010100101010011.1)
  elseif state_timeout > 0 then
   fillp(0b0010010000011000.1)
  end
 end

 if state == state_freeze_cam_out then
  if state_timeout > 6 then
   fillp(0b0010010000011000.1)
  elseif state_timeout > 3 then
   fillp(0b1010100101010011.1)
  elseif state_timeout > 0 then
   fillp(0b0111110110111110.1)
  end
 end

 -- draw cam walls

 if powers.freeze_cam == pow_on or state == state_freeze_cam_in or state == state_freeze_cam_out then
  rectfill(0,0,127,2,14)
  rectfill(0,0,2,127,14)
  rectfill(0,125,127,127,14)
  rectfill(125,0,127,127,14)
  line(3,3,124,3,7)
  line(3,3,3,124,7)
  line(124,3,124,124,7)
  line(3,124,124,124,7)
  fillp()
 end

 -- draw hud
 local hud_x = 95
 local hud_y = 1
 local hud_inc = 8

 local po = {powers.shot, powers.freeze_cam, powers.free_cam, powers.wrap_cam}
 for i=1,power_slots do
  if po[i] == pow_off then
   pal(14, 6)
   pal(2, 5)
   pal(12, 6)
   pal(1, 5)
   pal(11, 6)
   pal(3, 5)
  end
  if po[i] == pow_none then
   spr(116,hud_x,hud_y,1,1,false,false)
  else
   spr(116+i,hud_x,hud_y,1,1,false,false)
  end
  hud_x += hud_inc
  pal()
 end

 if state == state_menu then
  draw_menu()
 end


end

function draw_object(obj)

 if obj.type.draw ~=nil then
  obj.type.draw(obj)
 elseif obj.spr > 0 then
  spr(obj.spr,obj.x,obj.y,1,1,obj.flip.x,obj.flip.y)
 end

end


function draw_menu()

 -- draw menu background

 local menu_x = 10
 local menu_y = 10
 local menu_w = 80
 local menu_h = 80

 circ(menu_x + 4, menu_y + 4, 4, 7)
 circ(menu_x + menu_w - 4, menu_y + 4, 4, 7)
 circ(menu_x + 4, menu_y + menu_h - 4, 4, 7)
 circ(menu_x + menu_w - 4, menu_y + menu_h - 4, 4, 7)
 rect(menu_x, menu_y + 4, menu_x + menu_w, menu_y + menu_h - 4, 7)
 rect(menu_x + 4, menu_y, menu_x + menu_w - 4, menu_y + menu_h, 7)

 circfill(menu_x + 4, menu_y + 4, 3, 1)
 circfill(menu_x + menu_w - 4, menu_y + 4, 3, 1)
 circfill(menu_x + 4, menu_y + menu_h - 4, 3, 1)
 circfill(menu_x + menu_w - 4, menu_y + menu_h - 4, 3, 1)
 rectfill(menu_x + 1, menu_y + 5, menu_x + menu_w - 1, menu_y + menu_h - 5, 1)
 rectfill(menu_x + 5, menu_y + 1, menu_x + menu_w - 5, menu_y + menu_h - 1, 1)


 -- draw powers
 local powers_x = 20
 local powers_y = 80
 local powers_inc = 12

 local po = {powers.shot, powers.freeze_cam, powers.free_cam, powers.wrap_cam}
 for i=1,power_slots do
  if po[i] == pow_none then
   spr(116,powers_x,powers_y,1,1,false,false)
  else
   spr(116+i,powers_x,powers_y,1,1,false,false)
  end
  powers_x += powers_inc
 end

 -- draw cursor
 cursor_x = 20 + powers_inc * menu.cursor
 cursor_y = 79
 cursor_off = 1
 cursor_inc = 8

 line(cursor_x - cursor_off, cursor_y - cursor_off, cursor_x + cursor_off, cursor_y - cursor_off, 7)
 line(cursor_x - cursor_off, cursor_y - cursor_off, cursor_x - cursor_off, cursor_y + cursor_off, 7)

 line(cursor_x + cursor_inc - cursor_off, cursor_y - cursor_off, cursor_x + cursor_inc + cursor_off, cursor_y - cursor_off, 7)
 line(cursor_x + cursor_inc + cursor_off, cursor_y - cursor_off, cursor_x + cursor_inc + cursor_off, cursor_y + cursor_off, 7)

 line(cursor_x - cursor_off, cursor_y + cursor_inc - cursor_off, cursor_x - cursor_off, cursor_y + cursor_inc + cursor_off, 7)
 line(cursor_x - cursor_off, cursor_y + cursor_inc + cursor_off, cursor_x + cursor_off, cursor_y + cursor_inc + cursor_off, 7)

 line(cursor_x + cursor_inc + cursor_off, cursor_y + cursor_inc + cursor_off, cursor_x + cursor_inc - cursor_off, cursor_y + cursor_inc + cursor_off, 7)
 line(cursor_x + cursor_inc + cursor_off, cursor_y + cursor_inc + cursor_off, cursor_x + cursor_inc + cursor_off, cursor_y + cursor_inc - cursor_off, 7)

end


-->8
-- helper functions --
----------------------

function clamp(val,a,b)
 return max(a, min(b, val))
end

function appr(val,target,amount)
 return val > target
  and max(val - amount, target)
  or min(val + amount, target)
end

-- return a value between from and to
-- based on progression q (0-1),
-- and apply a sin
function interp_sin(from,to,q)
 local real_q = 0.5+sin(0.25+q/2)/2
 return from + real_q*(to-from)
end

function sign(v)
 return v>0 and 1 or
        v<0 and -1 or 0
end

function maybe()
 return rnd(1)<0.5
end

function solid_at(x,y,w,h)

 if powers.wrap_cam == pow_on then
  return solid_at_wrap(x,y,w,h)
 end

 for i=max(0,flr(x/8)),min(room.tw-1,(x+w-1)/8) do
  for j=max(0,flr(y/8)),min(room.th-1,(y+h-1)/8) do
   if fget(tile_at(i,j),0) then
    return true
   end
  end
 end
 return false
end

function solid_at_wrap(x,y,w,h)
 for i=max(0,flr(x/8)),min(room.tw-1,(x+w-1)/8) do
  for j=max(0,flr(y/8)),min(room.th-1,(y+h-1)/8) do
   if fget(tile_at(i,j),0) then
    return true
   end
  end

  if y <= fr_cam.y then
   for j=max(0,flr((y+128)/8)),min(min(room.th-1,(fr_cam.y+128)/8),(y+h-1+128)/8) do
    if fget(tile_at(i,j),0) then
     return true
    end
   end
  end

  if (y+h) >= fr_cam.y + 128 then
   for j=max(max(0,fr_cam.y/8),flr((y-128)/8)),min(room.th-1,(y+h-1-128)/8) do
    if fget(tile_at(i,j),0) then
     return true
    end
   end
  end

 end

 if x <= fr_cam.x then
 for i=max(0,flr((x+128)/8)),min(min(room.tw-1,(fr_cam.x+128)/8),(x+w-1+128)/8) do
  for j=max(0,flr(y/8)),min(room.th-1,(y+h-1)/8) do
   if fget(tile_at(i,j),0) then
    return true
   end
  end

  if y <= fr_cam.y then
   for j=max(0,flr((y+128)/8)),min(min(room.th-1,(fr_cam.y+128)/8),(y+h-1+128)/8) do
    if fget(tile_at(i,j),0) then
     return true
    end
   end
  end

  if (y+h) >= fr_cam.y + 128 then
   for j=max(max(0,fr_cam.y/8),flr((y-128)/8)),min(room.th-1,(y+h-1-128)/8) do
    if fget(tile_at(i,j),0) then
     return true
    end
   end
  end

 end
end

if (x+w) >= fr_cam.x + 128 then
for i=max(max(0,fr_cam.x/8),flr((x-128)/8)),min(room.tw-1,(x+w-1-128)/8) do
 for j=max(0,flr(y/8)),min(room.th-1,(y+h-1)/8) do
  if fget(tile_at(i,j),0) then
   return true
  end
 end

 if y <= fr_cam.y then
  for j=max(0,flr((y+128)/8)),min(min(room.th-1,(fr_cam.y+128)/8),(y+h-1+128)/8) do
   if fget(tile_at(i,j),0) then
    return true
   end
  end
 end

 if (y+h) >= fr_cam.y + 128 then
  for j=max(max(0,fr_cam.y/8),flr((y-128)/8)),min(room.th-1,(y+h-1-128)/8) do
   if fget(tile_at(i,j),0) then
    return true
   end
  end
 end

end
end



 return false
end


function tile_at(x,y)
 return mget(room.tx+x,room.ty+y)
end

__gfx__
000000000000000000000000008882000000000000000000000000000000000000000000000000000000000000cc0c000000c000000c00000000000000060000
0000000000888200008882000887b3300088820000888200008882000087b300008882000000000000ccc0000000cc000c0c000000c00000000c000000060000
000000000887b3300887b330088bbb300887b33007b3382008888820086bbb3008888820000088200cc7cc00cc0cc70000cc0c000000cc000000000000060000
00000000088bbb30088bbb3000888200088bbb300bbb38200887bb30086688200887bb3004988882cc777cc0c0cc77000000c700c00c0c0000c0c00000060000
0000000000888200008882000946690000888200668882f0008bb300008f8200008bb30084f887b3c77777c00cc77700c0cc77000000c7000000cc0000006000
00000000094669000946690009f644f0094669000694449009444900099449000944490004498b30cc777cc000cc770000c0c700000c0c00000c000000006000
0000000009f644f009f644f00800002009f644f00f44440009f664f0004444f004f440f0200f00000cc7cc00cc0cc700000c0c000c0cc0000000000000006000
0000000000800200080002000000000000800020000800200080620000800200008002000000000000ccc00000c0cc00000cc000000000000000c00000006000
5555555500000000000000000000000000000000557777550000000049999994499999949040904049449944666566650300b0b0000000000000000070000000
55555555000000000000000000000000000200005777c775008888009111111991114119040904094494944967656765003b3300007700000770070007000007
55000055000000000000000000020000002e2000577ccc7508888880911111199111911900000000000000006770677002888820007770700777000000000000
550000550070007000020000002e200002eee20077ccc77708788880911111199494041900000000000000000700070078988887077777700770000000000000
5500005500700070002e200002eee2002ee7ee20777cc77708888880911111199114094900000000000000000700070078888987077777700000700000000000
550000550677067700020000002e200002eee200777cc77708888880911111199111911900000000000000000000000008898880077777700000077000000000
55555555567656760000000000020000002e200077cccc7708888880911111199114111900000000000000000000000002888820070777000007077007000070
555555555666566600000000000000000002000077cccc7700888800499999944999999400000000000000000000000000288200000000007000000000000000
5777777557777777777777777777777577cccccccccccccccccccc77577777755555555555555555555555555500000007777770000000000000000000000000
77777777777777777777777777777777777cccccccccccccccccc777777777775555555555555550055555556670000077777777000777770000000000000000
777c77777777ccccc777777ccccc7777777cccccccccccccccccc777777777775555555555555500005555556777700077777777007766700000000000000000
77cccc77777cccccccc77cccccccc7777777cccccccccccccccc7777777cc7775555555555555000000555556660000077773377076777000000000000000000
77cccc7777cccccccccccccccccccc777777cccccccccccccccc777777cccc775555555555550000000055555500000077773377077660000777770000000000
777cc77777cc77ccccccccccccc7cc77777cccccccccccccccccc77777cccc775555555555500000000005556670000073773337077770000777767007700000
7777777777cc77cccccccccccccccc77777cccccccccccccccccc77777c7cc77555555555500000000000055677770007333bb37000000000000007700777770
5777777577cccccccccccccccccccc7777cccccccccccccccccccc7777cccc77555555555000000000000005666000000333bb30000000000000000000077777
77cccc7777cccccccccccccccccccc77577777777777777777777775777ccc775555555550000000000000050000066603333330000000000000000006060606
777ccc7777cccccccccccccccccccc77777777777777777777777777777cc7775055555555000000000000550007777603b333300000000000ee0ee060606060
777ccc7777cc7cccccccccccc77ccc777777ccc7777777777ccc7777777cc77755550055555000000000055500000766033333300000000000eeeee006060606
77ccc77777ccccccccccccccc77ccc77777ccccc7c7777ccccccc77777ccc777555500555555000000005555000000550333b33000000000000e8e0060606060
77ccc777777cccccccc77cccccccc777777ccccccc7777c7ccccc77777cccc7755555555555550000005555500000666003333000000b00000eeeee006060606
777cc7777777ccccc777777ccccc77777777ccc7777777777ccc777777cccc775505555555555500005555550007777600044000000b000000ee3ee060606060
777cc777777777777777777777777777777777777777777777777777777cc7775555555555555550055555550000076600044000030b00300000b00006060606
77cccc77577777777777777777777775577777777777777777777775577777755555555555555555555555550000005500999900030330300000b00060606060
5777755777577775077777777777777777777770077777707777777700000000cccccccc00000000000000000000000000000000000000000000000000000000
7777777777777777071111111111111111111170700077770000000000000000c77ccccc00000000000000000000000000000000000000000000000000000000
7777cc7777cc777771111111111111111111111770c777070000000000000000c77cc7cc00000000000000000000000000000000000000000000000000000000
777cccccccccc77771111111111111111111111770777c070c00000000000000cccccccc00000000000000000000000000006000000000000000000000000000
77cccccccccccc777111111111111111111111177777000700000c00eeee2000cccccccc00000000000000000000000000060600000000000000000000000000
57cc77ccccc7cc757111111111111111111111177770000700000000eeeee200cc7ccccc00000000000000000000000000d00060000000000000000000000000
577c77ccccccc77507111111111111111111117070000c0700000000eeeeee00ccccc7cc0000000000000000000000000d00000c000000000000000000000000
777cccccccccc7770777777777777777777777707000000700000000e2e22e00cccccccc000000000000000000000000d000000c000000000000000000000000
777cccccccccc7770000000000000000000000007000000700eeeeeeeeeeee000000000000000000000000000000000c0000000c000600000000000000000000
577cccccccccc77700007000000777000070007070cc000700e22e2222e22e00000000000000000000000000000000d000000000c060d0000000000000000000
57cc7cccc77ccc7500077700007000000070007070cc000700eeeeeeeeeeee0000000000000000000000000000000c00000000000d000d000000000000000000
77ccccccc77ccc7700707070007000000007070070000c0700eee222e22eee0000000000000000000000000000000c0000000000000000000000000000000000
777cccccccccc7770000700000700000000707007000000700eeeeeeeeeeee005555555506666600666666006600c00066666600066666006666660066666600
7777cc7777cc777700007000000777000000700070c0000700eeeeeeeeeeee00555555556666666066666660660c000066666660666666606666666066666660
77777777777777770000000000000000000000007000000700ee77eee7777e005555555566000660660000006600000066000000660000000066000066000000
57777577775577750000000000000000000000007000c007077777777777777055555555dd000000dddd0000dd000000dddd0000ddddddd000dd0000dddd0000
000000000000000000000000000000000000000000aaaa000076aa0000aaaa0000aaaa00dd000dd0dd000000dd0000d0dd000000000000d000dd0000dd000000
00aaaaaaaaaaaa000000700000000000000000000aaeeaa0076eeaa00aaee6700aaeeaa0ddddddd0dddddd00ddddddd0dddddd00ddddddd000dd0000dddddd00
0a999999999999a0000007000000000000000000aaaee2aa76aee2aaaaae676aaaaee2aa0ddddd00ddddddd0ddddddd0ddddddd00ddddd0000dd0000ddddddd0
a99aaaaaaaaaa99a007777700000000000000000aaaee2aa6aaee2aaaaa676aaaaaee2aa00000000000000000000000000000000000000000000000000000000
a9aaaaaaaaaaaa9a000007000000000000000000aaaa22aaaaaa22aaaa676aaaaaaa22a60000000000000c000000000000000000000000000000c00000000000
a99999999999999a000070000000000000000000aaaeeaaaaaaeeaaaa676eaaaaaaeea67000000000000c00000000000000000000000000000000c0000000000
a99999999999999a0000000000000000000000000aaa22a00aaa22a0076a22a00aaaa6700000000000cc0000000000000000000000000000000000c000000000
a99999999999999a00000000000000000000000000aaaa0000aaaa0000aaaa0000aa6700000000000c000000000000000000000000000000000000c000000000
aaaaaaaaaaaaaaaa0000000000000000000000000077777000777770007777700077777000000000c0000000000000000000000000000000000000c000000000
a49494a11a49494a0000000000000000000000000799999707eeeee707c111c707bb3bb70000000100000000000000000000000000000000000000c00c000000
a494a4a11a4a494a0000000000000000000000000799a99707e222e7071c1c1707b333b7000000c0000000000000000000000000000000000000001010c00000
a49444aaaa44494a099999900000000000000000079aaa9707e222e70711111707333337000001000000000000000000000000000000000000000001000c0000
a49999aaaa99994a0944449000000000000000000799a99707e222e7071c1c1707b333b700000100000000000000000000000000000000000000000000010000
a49444999944494a0944449000000000000000000799999707eeeee707c111c707bb3bb700000100000000000000000000000000000000000000000000001000
a494a444444a494a0999999000000000000000000077777000777770007777700077777000000000000000000000000000000000000000000000000000000000
a49499999999494a0009900000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010
00000000000000008242525252528452339200001323232352232323232352230000000000000000b302000013232352526200a2828342525223232323232323
00000000000000a20182920013232352363636462535353545550000005525355284525262b20000000000004252525262828282425284525252845252525252
00000000000085868242845252525252b1006100b1b1b1b103b1b1b1b1b103b100000000000000111102000000a282425233000000a213233300009200008392
000000000000110000a2000000a28213000000002636363646550000005525355252528462b2a300000000004252845262828382132323232323232352528452
000000000000a201821323525284525200000000000000007300000000007300000000000000b343536300410000011362b2000000000000000000000000a200
0000000000b302b2002100000000a282000000000000000000560000005526365252522333b28292001111024252525262019200829200000000a28213525252
0000000000000000a2828242525252840000000000000000b10000000000b1000000000000000000b3435363930000b162273737373737373737374711000061
000000110000b100b302b20000006182000000000000000000000000005600005252338282828201a31222225252525262820000a20011111100008283425252
0000000000000093a382824252525252000061000011000000000011000000001100000000000000000000020182001152222222222222222222222232b20000
0000b302b200000000b10000000000a200000000000000009300000000000000846282828283828282132323528452526292000000112434440000a282425284
00000000000000a2828382428452525200000000b302b2936100b302b20061007293a30000000000000000b1a282931252845252525252232323232362b20000
000000b10000001100000000000000000000000093000086820000a3000000005262828201a200a282829200132323236211111111243535450000b312525252
00000000000000008282821323232323820000a300b1a382930000b100000000738283931100000000000011a382821323232323528462829200a20173b20061
000000000000b302b2000061000000000000a385828286828282828293000000526283829200000000a20000000000005222222232263636460000b342525252
00000011111111a3828201b1b1b1b1b182938282930082820000000000000000b100a282721100000000b372828283b122222232132333610000869200000000
00100000000000b1000000000000000086938282828201920000a20182a37686526282829300000000000000000000005252845252328283920000b342845252
00008612222232828382829300000000828282828283829200000000000061001100a382737200000000b373a2829211525284628382a2000000a20000000000
00021111111111111111111111110061828282a28382820000000000828282825262829200000000000000000000000052525252526201a2000000b342525252
00000113235252225353536300000000828300a282828201939300001100000072828292b1039300000000b100a282125223526292000000000000a300000000
0043535353535353535353535363b2008282920082829200061600a3828382a28462000000000000000000000000000052845252526292000011111142525252
0000a28282132362b1b1b1b1000000009200000000a28282828293b372b2000073820100110382a3000000110082821362101333610000000000008293000000
0002828382828202828282828272b20083820000a282d3000717f38282920000526200000000000093000000000000005252525284620000b312223213528452
000000828392b30300000000002100000000000000000082828282b303b20000b1a282837203820193000072a38292b162710000000000009300008382000000
00b1a282820182b1a28283a28273b200828293000082122232122232820000a3233300000000000082920000000000002323232323330000b342525232135252
000000a28200b37300000000a37200000010000000111111118283b373b200a30000828273039200828300738283001162930000000000008200008282920000
0000009261a28200008261008282000001920000000213233342846282243434000000000000000082000085860000008382829200000000b342528452321323
0000100082000082000000a2820300002222321111125353630182829200008300009200b1030000a28200008282001262829200000000a38292008282000000
00858600008282a3828293008292610082001000001222222252525232253535000000f3100000a3820000a2010000008292000000009300b342525252522222
0400122232b200839321008683039300528452222262c000a28282820000a38210000000a3738000008293008292001362820000000000828300a38201000000
00a282828292a2828283828282000000343434344442528452525252622535350000001263000083829300008200c1008210d3e300a38200b342525252845252
1232425262b28682827282820103820052525252846200000082829200008282320000008382930000a28201820000b162839300000000828200828282930000
0000008382000000a28201820000000035353535454252525252528462253535000000032444008282820000829300002222223201828393b342525252525252
525252525262b2b1b1b1132323526200845223232323232352522323233382825252525252525252525284522333b2822323232323526282820000b342525252
52845252525252848452525262838242528452522333828292425223232352520000000000000000000000000000000000000000000000000000000000000000
525252845262b2000000b1b1b142620023338276000000824233b2a282018283525252845252232323235262b1b10083921000a382426283920000b342232323
2323232323232323232323526201821352522333b1b1018241133383828242840000000000000000000000000000000000000000000000000000000000000000
525252525262b20000000000a242627682828392000011a273b200a382729200525252525233b1b1b1b11333000000825353536382426282410000b30382a2a2
a1829200a2828382820182426200a2835262b1b10000831232b2000080014252000000000000a300000000000000000000000000000000000000000000000000
528452232333b20000001100824262928201a20000b3720092000000830300002323525262b200000000b3720000a382828283828242522232b200b373928000
000100110092a2829211a2133300a3825262b2000000a21333b20000868242520000000000000100009300000000000000000000000000000000000000000000
525262122232b200a37672b2a24262838292000000b30300000000a3820300002232132333b200000000b303829300a2838292019242845262b2000000000000
00a2b302b2a36182b302b200110000825262b200000000b1b10000a283a2425200000000a30082000083000000000000000000000094a4b4c4d4e4f400000000
525262428462b200a28303b2214262928300000000b3030000000000a203e3415252222232b200000000b30392000000829200000042525262b2000000000000
000000b100a2828200b100b302b211a25262b200000000000000000092b3428400000000827682000001009300000000000000000095a5b5c5d5e5f500000000
232333132362b221008203b2711333008293858693b3031111111111114222225252845262b200001100b303b2000000821111111142528462b2000000000000
000000000000110176851100b1b3026184621111111100000061000000b3135200000000828382670082768200000000000000000096a6b6c6d6e6f600000000
82000000a203117200a203b200010193828283824353235353535353535252845252525262b200b37200b303b2000000824353535323235262b2000011000000
0000000000b30282828372b26100b100525232122232b200000000000000b14200000000a28282123282839200000000000000000097a7b7c7d7e7f700000000
9200110000135362b2001353535353539200a2000001828282829200b34252522323232362b261b30300b3030000000092b1b1b1b1b1b34262b200b372b20000
001100000000b1a2828273b200000000232333132333b200001111000000b342000000868382125252328293a300000000000000000000000000000000000000
00b372b200a28303b2000000a28293b3000000000000a2828382827612525252b1b1b1b173b200b30393b30361000000000000000000b34262b271b303b20000
b302b211000000110092b100000000a3b1b1b1b1b1b10011111232110000b342000000a282125284525232828386000000000000000000000000000000000000
80b303b20000820311111111008283b311111111110000829200928242528452000000a3820000b30382b37300000000000000000000b3426211111103b20000
00b1b302b200b372b200000000000082b21000000000b31222522363b200b3138585868292425252525262018282860000000000000000000000000000000000
00b373b20000a21353535363008292b32222222232111102b20000a21323525200000001839200b3038282820000000011111111930011425222222233b20000
100000b10000b303b200000000858682b27100000000b3425233b1b1000000b182018283001323525284629200a2820000000000000000000000000000000000
9300b100000000b1b1b1b1b100a200b323232323235363b100000000b1b1135200000000820000b30382839200000000222222328283432323232333b2000000
329300000000b373b200000000a20182111111110000b31333b100a30061000000a28293f3123242522333020000820000000000000000000000000000000000
829200001000410000000000000000b39310d30000a28200000000000000824200000086827600b30300a282760000005252526200828200a30182a2006100a3
62820000000000b100000093a382838222222232b20000b1b1000083000000860000122222526213331222328293827600000000000000000000000000000000
017685a31222321111111111002100b322223293000182930000000080a301131000a383829200b373000083920000005284526200a282828283920000000082
62839321000000000000a3828282820152845262b261000093000082a300a3821000135252845222225252523201838200000000000000000000000000000000
828382824252522222222232007100b352526282a38283820000000000838282320001828200000083000082010000005252526271718283820000000000a382
628201729300000000a282828382828252528462b20000a38300a382018283821222324252525252525284525222223200000000000000000000000000000000
__label__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000700000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000770000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000770000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000007000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000070000000000000000006000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000060600000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000d00060000000000000066000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000d00000c000000000000066000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000d000000c000000000000000000000000000000000000000000000000060000000000
00000000000000000000000000000000000000000000000000000000000c0000000c000600000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000d000000000c060d0000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000c00000000000d000d000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000006666600666666006600c00066666600066666006666660066666600000000000000000000000000000000000000
0000000000000000000000000000000000006666666066666660660c000066666660666666606666666066666660000000000000000000000000000000000000
00000000000000000000000000000000000066000660660000006600000066000000660000000066000066000000000000000000000000000000000000000000
000000000000000000000000000000000000dd000000dddd0000dd000000dddd0000ddddddd000dd0000dddd0000000000000000000000000000000000000000
000000000000000000000000000000000000dd000dd0dd000000dd0000d0dd000000000000d000dd0000dd000000000000000000000000000000000000000000
000000000000000000000000000000000000ddddddd0dddddd00ddddddd0dddddd00ddddddd000dd0000dddddd00000000000000000000000000000000000000
0000000000000000000000000000000000000ddddd00ddddddd0ddddddd0ddddddd00ddddd0000dd0000ddddddd0000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000c000000000000000000000000000000c00000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000c00000000000000000000000000000000c0000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000cc0000000000000000000000000000000000c000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000c000000000000000000000000000000000000c000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000c0000000000000000000000000000000000000c000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000100000000000000000000000000000000000000c00c000000000000000000000000000000000000000000
000000000000000000000000000000000000000000c0000000000000000000000000000000000000001010c00000000000000000000000000000000000000000
000000000000000000000000000000000000000001000000000000000000000000000000000000000001000c0000000000000000000000000000000000000000
00000000000000000000000000000000000000000100000000000000000000000000000000000000000000010000000600000000000000000000000000000000
00000000000000000000000000000000000000000100000000000000000000000000000000000000000000001000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000005050000005500000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000005050050050006000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000500555050000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000005050050050000000000000600000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000005050000005500000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000070000000000660000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000660000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000007000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000055505550555055500000555050500550555005500550550000000000000000000000000000000000000000
00000000000000000000000000000000000000000055505050050005000000050050505050505050005050505000000000000000000000000000000000000000
00000000000000000000000000000000000000000050505550050005000000050055505050550055505050505000000000000000000000000000000000000000
00000000000000000000000000000000000000000050505050050005000000050050505050505000505050505000000000000000000000000000000000000000
00000000000000000000000000000000000000000050505050050005000000050050505500505055005500505000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000605500055055505000000055505550555055505050000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000005050505050005000000050505000505050505050000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000005050505055005000000055005500550055005550000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000005050505050005000000050505000505050500050000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000005050550055505550000055505550505050505550000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__gff__
0000000000000000000000000000000004020000000000000000000200000000030303030303030304040402020000000303030303030303040404020202020000001313131302020302020202020002000013131313020204020202020202020000131313020202020202020202020200000813131300000002020202020202
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
2525252525252525252525254825252631333132330000000000000000000025250025252525323328382828312525253232323233000000313232323232323232330000002432323233313232322525252525482525252525252526282824252548252525262828282824254825252526282828283132323225482525252525
252525252525252548482624252548260000003d000015003e0000000000003f3f0025252526002a2828292810244825282828290000000028282900000000002810000000372829000000002a2831482525252525482525323232332828242525254825323338282a283132252548252628382828282a2a2831323232322525
252525254825254825252631323232333435353620203435353536191919313225252548253300002900002a0031252528382900003a676838280000000000003828393e003a2800000000000028002425253232323232332122222328282425252532332828282900002a283132252526282828282900002a28282838282448
2525252525252525252526272b0000000000000000000000000000000021222225002525260000000000000000003125290000000021222328280000000000002a2828343536290000000000002839242526212223202123313232332828242548262b000000000000001c00003b242526282828000000000028282828282425
2525252525254825482526302b0000000000000000000000000000002724252525003125333d0000000000000000003100001c3a3a31252620283900000000000010282828290000000011113a2828313233242526103133202828282838242525262b000000000000000000003b2425262a2828670016002a28283828282425
2525254825252525252526372b000000000000004a724a654a4a21233731323225000037212223000000000000000024395868282828242628290000000000002a2828290000000000002123283828292828313233282829002a002a2828242525332b0c00000011110000000c3b314826112810000000006828282828282425
2525482525252525482526212300001111111111343535353536313321222222251a000024252611111111000000002424382828283831332800000017170000002a000000001111000024261028290028281b1b1b282800000000002a2125482628390000003b34362b000000002824252328283a67003a28282829002a3132
25252525254825252525263133000021233422232122222222232122252525252600003a313232353535366758000024242828281028212329000000000000000000000000003436003a2426282800003828390000002a29000000000031323226101000000000282839000000002a2425332828283800282828390000001700
2532323232323232323233000000002432363126242525252526242525252525260000282828282820202828283921222829002a28282426000000000000000000000000000020382828312523000000282828290000000000163a67682828003338280b00000010382800000b00003133282828282868282828280000001700
330000000000000000000000000000373435363731323232323324252525252526003a283828102900002a28382824252a0000002838242600000017170000000000000000002728282a283133390000282900000000000000002a28282829002a2839000000002a282900000000000028282838282828282828290000000000
00000000000000000000000000002122222222222222222222222525252525252600002a282828000000002810282425000000002a282426000000000000000000000000000037280000002a28283900280000003928390000000000282800000028290000002a2828000000000000002a282828281028282828675800000000
000000000000000000000000000024252525252525252525252525252525252526000000002a281111111128282824480000003a28283133000000000000171700013f0000002029000000003828000028013a28281028580000003a28290000002a280c0000003a380c00000000000c00002a2828282828292828290000003a
00000021230000000000000000002425252525252525252525252525252525252600000000002834222236292a0024253e003a3828292a00000000000000000035353536000020000000003d2a28671422222328282828283900582838283d00003a290000000028280000000000000000002a28282a29000058100012002a28
22222225260000000000000000002425252525252525252525252525252525252600000000002a282426290000002425222222232900000000000000171700002a282039003a2000003a003435353535252525222222232828282810282821220b10000000000b28100000000b0000002c00002838000000002a283917000028
2548252525222222222222222222482525252525252525252525252525252525222223000012002a24260000001224252525252600000000171700000000000000382028392827080028676820282828254825252525262a28282122222225253a28013d0000006828390000000000003c0168282800171717003a2800003a28
25252525252525252525252525252525252525252525252525252525252525252548262222272222242622222221252525254826171700000000000000000000002a2028102830003a282828202828282525252548252600002a2425252548252821222300000028282800000000000022222223286700000000282839002838
2532330000002432323232323232252525252628282828242532323232254825253232323232323225262525252448252525253300000000000000000000005225253232323233313232323233282900262829286700000000002828313232322525253233282800312525482525254825254826283828313232323232322548
26282800000030402a282828282824252548262838282831333828290031322526280000163a28283133282838242525482526000000000000000000000000522526000016000000002a10282838390026281a3820393d000000002a3828282825252628282829003b2425323232323232323233282828282828102828203125
3328390000003700002a3828002a2425252526282828282028292a0000002a313328111111282828000028002a312525252526000000000000000000000000522526000000001111000000292a28290026283a2820102011111121222328281025252628382800003b24262b002a2a38282828282829002a2800282838282831
28281029000000000000282839002448252526282900282067000000000000003810212223283829003a1029002a242532323367000000000000000000004200252639000000212300000000002122222522222321222321222324482628282832323328282800003b31332b00000028102829000000000029002a2828282900
2828280016000000162a2828280024252525262700002a2029000000000000002834252533292a0000002a00111124252223282800002c46472c00000042535325262800003a242600001600002425252525482631323331323324252620283822222328292867000028290000000000283800111100001200000028292a1600
283828000000000000003a28290024254825263700000029000000000000003a293b2426283900000000003b212225252526382867003c56573c4243435363633233283900282426111111111124252525482526201b1b1b1b1b24252628282825252600002a28143a2900000000000028293b21230000170000112867000000
2828286758000000586828380000313232323320000000000000000000272828003b2426290000000000003b312548252533282828392122222352535364000029002a28382831323535353522254825252525252300000000003132332810284825261111113435361111111100000000003b3133111111111127282900003b
2828282810290000002a28286700002835353536111100000000000011302838003b3133000000000000002a28313225262a282810282425252662636400000000160028282829000000000031322525252525252667580000002000002a28282525323535352222222222353639000000003b34353535353536303800000017
282900002a0000000000382a29003a282828283436200000000000002030282800002a29000011110000000028282831260029002a282448252523000000000039003a282900000000000000002831322525482526382900000017000058682832331028293b2448252526282828000000003b201b1b1b1b1b1b302800000017
283a0000000000000000280000002828283810292a000000000000002a3710281111111111112136000000002a28380b2600000000212525252526001c0000002828281000000000001100002a382829252525252628000000001700002a212228282908003b242525482628282912000000001b00000000000030290000003b
3829000000000000003a102900002838282828000000000000000000002a2828223535353535330000000000002828393300000000313225252533000000000028382829000000003b202b00682828003232323233290000000000000000312528280000003b3132322526382800170000000000000000110000370000000000
290000000000000000002a000000282928292a0000000000000000000000282a332838282829000000000000001028280000000042434424252628390000000028002a0000110000001b002a2010292c1b1b1b1b0000000000000000000010312829160000001b1b1b313328106700000000001100003a2700001b0000000000
00000000000011111100000000002a3a2a0000000000000000000000002a2800282829002a000000000000000028282800000000525354244826282800000000290000003b202b39000000002900003c000000000000000000000000000028282800000000000000001b1b2a2829000001000027390038300000000000000000
1111201111112122230000001212002a00000000000000000000000000002900290000000000000000002a6768282900003f01005253542425262810673a3900013f0000002a3829001100000000002101000000000000003a67000000002a382867586800000100000000682800000021230037282928300000000000000000
22222222222324482611111120201111002739000017170000001717000000000001000000001717000000282838393a0021222352535424253328282838290022232b00000828393b27000000001424230000001200000028290000000000282828102867001717171717282839000031333927101228370000000000000000
254825252526242526212222222222223a303800000000000000000000000000001717000000000000003a28282828280024252652535424262828282828283925262b00003a28103b30000000212225260000002700003a28000000000000282838282828390000005868283828000022233830281728270000000000000000
__sfx__
0002000036370234702f3701d4702a37017470273701347023370114701e3700e4701a3600c46016350084401233005420196001960019600196003f6003f6003f6003f6003f6003f6003f6003f6003f6003f600
0002000011070130701a0702407000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300000d07010070160702207000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200000642008420094200b420224402a4503c6503b6503b6503965036650326502d6502865024640216401d6401a64016630116300e6300b62007620056100361010600106000060000600006000060000600
000400000f0701e070120702207017070260701b0602c060210503105027040360402b0303a030300203e02035010000000000000000000000000000000000000000000000000000000000000000000000000000
000300000977009770097600975008740077300672005715357003470034700347003470034700347003570035700357003570035700347003470034700337003370033700337000070000700007000070000700
00030000241700e1702d1701617034170201603b160281503f1402f120281101d1101011003110001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
00020000101101211014110161101a120201202613032140321403410000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
00030000070700a0700e0701007016070220702f0702f0602c0602c0502f0502f0402c0402c0302f0202f0102c000000000000000000000000000000000000000000000000000000000000000000000000000000
0003000005110071303f6403f6403f6303f6203f6103f6153f6003f6003f600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600
011000200177500605017750170523655017750160500605017750060501705076052365500605017750060501775017050177500605236550177501605006050177500605256050160523655256050177523655
002000001d0401d0401d0301d020180401804018030180201b0301b02022040220461f0351f03016040160401d0401d0401d002130611803018030180021f061240502202016040130201d0401b0221804018040
00100000070700706007050110000707007060030510f0700a0700a0600a0500a0000a0700a0600505005040030700306003000030500c0700c0601105016070160600f071050500a07005050030510a0700a060
000400000c5501c5601057023570195702c5702157037570285703b5702c5703e560315503e540315303e530315203f520315203f520315103f510315103f510315103f510315103f50000500005000050000500
000400002f7402b760267701d7701577015770197701c750177300170015700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
00030000096450e655066550a6550d6550565511655076550c655046550965511645086350d615006050060500605006050060500605006050060500605006050060500605006050060500605006050060500605
011000001f37518375273752730027300243001d300263002a3001c30019300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300
011000002953429554295741d540225702256018570185701856018500185701856000500165701657216562275142753427554275741f5701f5601f500135201b55135530305602454029570295602257022560
011000200a0700a0500f0710f0500a0600a040110701105007000070001107011050070600704000000000000a0700a0500f0700f0500a0600a0401307113050000000000013070130500f0700f0500000000000
002000002204022030220201b0112404024030270501f0202b0402202027050220202904029030290201601022040220302b0401b030240422403227040180301d0401d0301f0521f0421f0301d0211d0401d030
0108002001770017753f6253b6003c6003b6003f6253160023650236553c600000003f62500000017750170001770017753f6003f6003f625000003f62500000236502365500000000003f625000000000000000
002000200a1400a1300a1201113011120111101b1401b13018152181421813213140131401313013120131100f1400f1300f12011130111201111016142161321315013140131301312013110131101311013100
001000202e750377502e730377302e720377202e71037710227502b750227302b7301d750247501d730247301f750277501f730277301f7202772029750307502973030730297203072029710307102971030710
000600001877035770357703576035750357403573035720357103570000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
001800202945035710294403571029430377102942037710224503571022440274503c710274403c710274202e450357102e440357102e430377102e420377102e410244402b45035710294503c710294403c710
0018002005570055700557005570055700000005570075700a5700a5700a570000000a570000000a5700357005570055700557000000055700557005570000000a570075700c5700c5700f570000000a57007570
010c00103b6352e6003b625000003b61500000000003360033640336303362033610336103f6003f6150000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000c002024450307102b4503071024440307002b44037700244203a7102b4203a71024410357102b410357101d45033710244503c7101d4403771024440337001d42035700244202e7101d4102e7102441037700
011800200c5700c5600c550000001157011560115500c5000c5700c5600f5710f56013570135600a5700a5600c5700c5600c550000000f5700f5600f550000000a5700a5600a5500f50011570115600a5700a560
001800200c5700c5600c55000000115701156011550000000c5700c5600f5710f56013570135600f5700f5600c5700c5700c5600c5600c5500c5300c5000c5000c5000a5000a5000a50011500115000a5000a500
000c0020247712477024762247523a0103a010187523a0103501035010187523501018750370003700037000227712277222762227001f7711f7721f762247002277122772227620070027771277722776200700
000c0020247712477024762247523a0103a010187503a01035010350101875035010187501870018700007001f7711f7701f7621f7521870000700187511b7002277122770227622275237012370123701237002
000c0000247712477024772247722476224752247422473224722247120070000700007000070000700007002e0002e0002e0102e010350103501033011330102b0102b0102b0102b00030010300123001230012
000c00200c3320c3320c3220c3220c3120c3120c3120c3020c3320c3320c3220c3220c3120c3120c3120c30207332073320732207322073120731207312073020a3320a3320a3220a3220a3120a3120a3120a302
000c00000c3300c3300c3200c3200c3100c3100c3103a0000c3300c3300c3200c3200c3100c3100c3103f0000a3300a3201333013320073300732007310113000a3300a3200a3103c0000f3300f3200f3103a000
00040000336251a605000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005
000c00000c3300c3300c3300c3200c3200c3200c3100c3100c3100c31000000000000000000000000000000000000000000000000000000000000000000000000a3000a3000a3000a3000a3310a3300332103320
001000000c3500c3400c3300c3200f3500f3400f3300f320183501834013350133401835013350163401d36022370223702236022350223402232013300133001830018300133001330016300163001d3001d300
000c0000242752b27530275242652b26530265242552b25530255242452b24530245242352b23530235242252b22530225242152b21530215242052b20530205242052b205302053a2052e205002050020500205
001000102f65501075010753f615010753f6152f65501075010753f615010753f6152f6553f615010753f61500005000050000500005000050000500005000050000500005000050000500005000050000500005
0010000016270162701f2711f2701f2701f270182711827013271132701d2711d270162711627016270162701b2711b2701b2701b270000001b200000001b2000000000000000000000000000000000000000000
00080020245753057524545305451b565275651f5752b5751f5452b5451f5352b5351f5252b5251f5152b5151b575275751b545275451b535275351d575295751d545295451d535295351f5752b5751f5452b545
002000200c2650c2650c2550c2550c2450c2450c2350a2310f2650f2650f2550f2550f2450f2450f2351623113265132651325513255132451324513235132351322507240162701326113250132420f2600f250
00100000072750726507255072450f2650f2550c2750c2650c2550c2450c2350c22507275072650725507245072750726507255072450c2650c25511275112651125511245132651325516275162651625516245
000800201f5702b5701f5402b54018550245501b570275701b540275401857024570185402454018530245301b570275701b540275401d530295301d520295201f5702b5701f5402b5401f5302b5301b55027550
00100020112751126511255112451326513255182751826518255182451d2651d2550f2651824513275162550f2750f2650f2550f2451126511255162751626516255162451b2651b255222751f2451826513235
00100010010752f655010753f6152f6553f615010753f615010753f6152f655010752f6553f615010753f61500005000050000500005000050000500005000050000500005000050000500005000050000500005
001000100107501075010753f6152f6553f6153f61501075010753f615010753f6152f6553f6152f6553f61500005000050000500005000050000500005000050000500005000050000500005000050000500005
002000002904029040290302b031290242b021290142b01133044300412e0442e03030044300302b0412b0302e0442e0402e030300312e024300212e024300212b0442e0412b0342e0212b0442b0402903129022
000800202451524515245252452524535245352454524545245552455524565245652457500505245750050524565005052456500505245550050524555005052454500505245350050524525005052451500505
000800201f5151f5151f5251f5251f5351f5351f5451f5451f5551f5551f5651f5651f575000051f575000051f565000051f565000051f555000051f555000051f545000051f535000051f525000051f51500005
000500000373005731077410c741137511b7612437030371275702e5712437030371275702e5712436030361275602e5612435030351275502e5512434030341275402e5412433030331275202e5212431030311
002000200c2750c2650c2550c2450c2350a2650a2550a2450f2750f2650f2550f2450f2350c2650c2550c2450c2750c2650c2550c2450c2350a2650a2550a2450f2750f2650f2550f2450f235112651125511245
002000001327513265132551324513235112651125511245162751626516255162451623513265132551324513275132651325513245132350f2650f2550f2450c25011231162650f24516272162520c2700c255
000300001f3302b33022530295301f3202b32022520295201f3102b31022510295101f3002b300225002950000000000000000000000000000000000000000000000000000000000000000000000000000000000
000b00002935500300293453037030360303551330524300243050030013305243002430500300003002430024305003000030000300003000030000300003000030000300003000030000300003000030000300
001000003c5753c5453c5353c5253c5153c51537555375453a5753a5553a5453a5353a5253a5253a5153a51535575355553554535545355353553535525355253551535515335753355533545335353352533515
00100000355753555535545355353552535525355153551537555375353357533555335453353533525335253a5753a5453a5353a5253a5153a51533575335553354533545335353353533525335253351533515
001000200c0600c0300c0500c0300c0500c0300c0100c0000c0600c0300c0500c0300c0500c0300c0100f0001106011030110501103011010110000a0600a0300a0500a0300a0500a0300a0500a0300a01000000
001000000506005030050500503005010050000706007030070500703007010000000f0600f0300f010000000c0600c0300c0500c0300c0500c0300c0500c0300c0500c0300c010000000c0600c0300c0100c000
0010000003625246150060503615246251b61522625036150060503615116253361522625006051d6250a61537625186152e6251d615006053761537625186152e6251d61511625036150060503615246251d615
00100020326103261032610326103161031610306102e6102a610256101b610136100f6100d6100c6100c6100c6100c6100c6100f610146101d610246102a6102e61030610316103361033610346103461034610
00400000302453020530235332252b23530205302253020530205302253020530205302153020530205302152b2452b2052b23527225292352b2052b2252b2052b2052b2252b2052b2052b2152b2052b2052b215
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
01 150a5644
00 0a160c44
00 0a160c44
00 0a0b0c44
00 14131244
00 0a160c44
00 0a160c44
02 0a111244
00 41424344
00 41424344
01 18191a44
00 18191a44
00 1c1b1a44
00 1d1b1a44
00 1f211a44
00 1f1a2144
00 1e1a2244
02 201a2444
00 41424344
00 41424344
01 2a272944
00 2a272944
00 2f2b2944
00 2f2b2c44
00 2f2b2944
00 2f2b2c44
00 2e2d3044
00 34312744
02 35322744
00 41424344
01 3d7e4344
00 3d7e4344
00 3d4a4344
02 3d3e4344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
01 383a3c44
02 393b3c44
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
