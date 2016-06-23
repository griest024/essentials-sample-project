class PokemonTemp
  attr_reader :berryPlantData

  def pbGetBerryPlantData(item)
    if !@berryPlantData
      pbRgssOpen("Data/berryplants.dat","rb"){|f|
         @berryPlantData=Marshal.load(f)
      }
    end
    return @berryPlantData[item] if @berryPlantData && @berryPlantData[item]!=nil
    return [3,15,2,5] # Hours/stage, drying/hour, min yield, max yield
  end
end



Events.onSpritesetCreate+=proc{|sender,e|
   spriteset=e[0]
   viewport=e[1]
   map=spriteset.map
   for i in map.events.keys
     if map.events[i].name=="BerryPlant"
       spriteset.addUserSprite(BerryPlantMoistureSprite.new(map.events[i],map,viewport))
       spriteset.addUserSprite(BerryPlantSprite.new(map.events[i],map,viewport))
     end
   end
}



class BerryPlantMoistureSprite
  def initialize(event,map,viewport=nil)
    @event=event
    @map=map
    @light = IconSprite.new(0,0,viewport)
    @light.ox=16
    @light.oy=24
    @oldmoisture=-1   # -1=none, 0=dry, 1=damp, 2=wet
    updateGraphic
    @disposed=false
  end

  def disposed?
    return @disposed
  end

  def dispose
    @light.dispose
    @map=nil
    @event=nil
    @disposed=true
  end

  def updateGraphic
    case @oldmoisture
    when -1
      @light.setBitmap("")
    when 0
      @light.setBitmap("Graphics/Characters/berrytreeDry")
    when 1
      @light.setBitmap("Graphics/Characters/berrytreeDamp")
    when 2
      @light.setBitmap("Graphics/Characters/berrytreeWet")
    end
  end

  def update
    return if !@light || !@event
    newmoisture=-1
    if @event.variable && @event.variable.length>6 && @event.variable[1]>0
      # Berry was planted, show moisture patch
      newmoisture=(@event.variable[4]>50) ? 2 : (@event.variable[4]>0) ? 1 : 0
    end
    if @oldmoisture!=newmoisture
      @oldmoisture=newmoisture
      updateGraphic
    end
    @light.update
    if (Object.const_defined?(:ScreenPosHelper) rescue false)
      @light.x = ScreenPosHelper.pbScreenX(@event)
      @light.y = ScreenPosHelper.pbScreenY(@event)
      @light.zoom_x = ScreenPosHelper.pbScreenZoomX(@event)
    else
      @light.x = @event.screen_x
      @light.y = @event.screen_y
      @light.zoom_x = 1.0
    end
    @light.zoom_y = @light.zoom_x
    pbDayNightTint(@light)
  end
end



class BerryPlantSprite
  REPLANTS = 9

  def initialize(event,map,viewport)
    @event=event
    @map=map
    @oldstage=0
    @disposed=false
    berryData=event.variable
    return if !berryData
    @oldstage=berryData[0]
    @event.character_name=""
    berryData=updatePlantDetails(berryData)
    setGraphic(berryData,true)      # Set the event's graphic
    @event.setVariable(berryData)   # Set new berry data
  end

  def dispose
    @event=nil
    @map=nil
    @disposed=true
  end

  def disposed?
    @disposed
  end

  def update                      # Constantly updates, used only to immediately
    berryData=@event.variable     # change sprite when planting/picking berries
    if berryData
      berryData=updatePlantDetails(berryData) if berryData.length>6
      setGraphic(berryData)
      @event.setVariable(berryData)
    end
  end

  def updatePlantDetails(berryData)
    return berryData if berryData[0]==0
    berryvalues=$PokemonTemp.pbGetBerryPlantData(berryData[1])
    timeperstage=berryvalues[0]*3600
    timenow=pbGetTimeNow
    if berryData.length>6
      # Gen 4 growth mechanisms
      # Check time elapsed since last check
      timeDiff=(timenow.to_i-berryData[3])   # in seconds
      return berryData if timeDiff<=0
      berryData[3]=timenow.to_i   # last updated now
      # Mulch modifiers
      dryingrate=berryvalues[1]
      maxreplants=REPLANTS
      ripestages=4
      if isConst?(berryData[7],PBItems,:GROWTHMULCH)
        timeperstage=(timeperstage*0.75).to_i
        dryingrate=(dryingrate*1.5).ceil
      elsif isConst?(berryData[7],PBItems,:DAMPMULCH)
        timeperstage=(timeperstage*1.25).to_i
        dryingrate=(dryingrate*0.5).floor
      elsif isConst?(berryData[7],PBItems,:GOOEYMULCH)
        maxreplants=(maxreplants*1.5).ceil
      elsif isConst?(berryData[7],PBItems,:STABLEMULCH)
        ripestages=6
      end
      # Cycle through all replants since last check
      loop do
        secondsalive=berryData[2]
        growinglife=(berryData[5]>0) ? 3 : 4 # number of growing stages
        numlifestages=growinglife+ripestages # number of growing + ripe stages
        # Should replant itself?
        if secondsalive+timeDiff>=timeperstage*numlifestages
          # Should replant
          if berryData[5]>=maxreplants   # Too many replants
            return [0,0,0,0,0,0,0,0]
          end
          # Replant
          berryData[0]=2   # replants start in sprouting stage
          berryData[2]=0   # seconds alive
          berryData[5]+=1  # add to replant count
          berryData[6]=0   # yield penalty
          timeDiff-=(timeperstage*numlifestages-secondsalive)
        else
          break
        end
      end
      # Update current stage and dampness
      if berryData[0]>0
        # Advance growth stage
        oldlifetime=berryData[2]
        newlifetime=oldlifetime+timeDiff
        if berryData[0]<5
          berryData[0]=1+(newlifetime/timeperstage).floor
          berryData[0]+=1 if berryData[5]>0   # replants start at stage 2
          berryData[0]=5 if berryData[0]>5
        end
        # Update the "seconds alive" counter
        berryData[2]=newlifetime
        # Reduce dampness, apply yield penalty if dry
        growinglife=(berryData[5]>0) ? 3 : 4 # number of growing stages
        oldhourtick=(oldlifetime/3600).floor
        newhourtick=(([newlifetime,timeperstage*growinglife].min)/3600).floor
        (newhourtick-oldhourtick).times do
          if berryData[4]>0
            berryData[4]=[berryData[4]-dryingrate,0].max
          else
            berryData[6]+=1
          end
        end
      end
    else
      # Gen 3 growth mechanics
      loop do
        if berryData[0]>0 && berryData[0]<5
          levels=0
          # Advance time
          timeDiff=(timenow.to_i-berryData[3]) # in seconds
          if timeDiff>=timeperstage
            levels+=1
            if timeDiff>=timeperstage*2
              levels+=1
              if timeDiff>=timeperstage*3
                levels+=1
                if timeDiff>=timeperstage*4
                  levels+=1
                end
              end
            end
          end
          levels=5-berryData[0] if levels>5-berryData[0]
          break if levels==0
          berryData[2]=false                  # not watered this stage
          berryData[3]+=levels*timeperstage   # add to time existed
          berryData[0]+=levels                # increase growth stage
          berryData[0]=5 if berryData[0]>5
        end
        if berryData[0]>=5
          # Advance time
          timeDiff=(timenow.to_i-berryData[3])   # in seconds
          if timeDiff>=timeperstage*4   # ripe for 4 times as long as a stage
            # Replant
            berryData[0]=2                      # replants start at stage 2
            berryData[2]=false                  # not watered this stage
            berryData[3]+=timeperstage*4        # add to time existed
            berryData[4]=0                      # reset total waterings count
            berryData[5]+=1                     # add to replanted count
            if berryData[5]>REPLANTS   # Too many replants
              berryData=[0,0,false,0,0,0]
              break
            end
          else
            break
          end
        end
      end
      # Check auto-watering
      if berryData[0]>0 && berryData[0]<5
        # Reset watering
        if $game_screen && 
           ($game_screen.weather_type==PBFieldWeather::Rain ||
           $game_screen.weather_type==PBFieldWeather::HeavyRain ||
           $game_screen.weather_type==PBFieldWeather::Storm)
          # If raining, plant is already watered
          if berryData[2]==false
            berryData[2]=true
            berryData[4]+=1
          end
        end
      end
    end
    return berryData
  end

  def setGraphic(berryData,fullcheck=false)
    return if !berryData || (@oldstage==berryData[0] && !fullcheck)
    case berryData[0]
    when 0
      @event.character_name=""
    when 1
      @event.character_name="berrytreeplanted"   # Common to all berries
      @event.turn_down
    else
      filename=sprintf("berrytree%s",getConstantName(PBItems,berryData[1])) rescue nil
      filename=sprintf("berrytree%03d",berryData[1]) if !pbResolveBitmap("Graphics/Characters/"+filename)
      if pbResolveBitmap("Graphics/Characters/"+filename)
        @event.character_name=filename
        case berryData[0]
        when 2; @event.turn_down    # X sprouted
        when 3; @event.turn_left    # X taller
        when 4; @event.turn_right   # X flowering
        when 5; @event.turn_up      # X berries
        end
      else
        @event.character_name="Object ball"
      end
      if @oldstage!=berryData[0] && berryData.length>6   # Gen 4 growth mechanisms
        $scene.spriteset.addUserAnimation(PLANT_SPARKLE_ANIMATION_ID,@event.x,@event.y) if $scene.spriteset
      end
    end
    @oldstage=berryData[0]
p "here",berryData,@oldstage if Input.trigger?(Input::CTRL)
  end
end



def pbBerryPlant
  interp=pbMapInterpreter
  thisEvent=interp.get_character(0)
  berryData=interp.getVariable
p berryData if Input.trigger?(Input::CTRL)
  if !berryData
    if NEWBERRYPLANTS
      berryData=[0,0,0,0,0,0,0,0]
    else
      berryData=[0,0,false,0,0,0]
    end
  end
  # Stop the event turning towards the player
  case berryData[0]
  when 1; thisEvent.turn_down  # X planted
  when 2; thisEvent.turn_down  # X sprouted
  when 3; thisEvent.turn_left  # X taller
  when 4; thisEvent.turn_right  # X flowering
  when 5; thisEvent.turn_up  # X berries
  end
  watering=[]
  watering.push(getConst(PBItems,:SPRAYDUCK))
  watering.push(getConst(PBItems,:SQUIRTBOTTLE))
  watering.push(getConst(PBItems,:WAILMERPAIL))
  watering.push(getConst(PBItems,:SPRINKLOTAD))
  watering.compact!
  berry=berryData[1]
  case berryData[0]
  when 0  # empty
    if NEWBERRYPLANTS
      # Gen 4 planting mechanics
      if !berryData[7] || berryData[7]==0 # No mulch used yet
        cmd=Kernel.pbMessage(_INTL("It's soft, earthy soil."),[
                            _INTL("Fertilize"),
                            _INTL("Plant Berry"),
                            _INTL("Exit")],-1)
        if cmd==0 # Fertilize
          ret=0
          pbFadeOutIn(99999){
             scene=PokemonBag_Scene.new
             screen=PokemonBagScreen.new(scene,$PokemonBag)
             ret=screen.pbChooseItemScreen
          }
          if ret>0
            if pbIsMulch?(ret)
              berryData[7]=ret
              Kernel.pbMessage(_INTL("The {1} was scattered on the soil.",PBItems.getName(ret)))
              if Kernel.pbConfirmMessage(_INTL("Want to plant a Berry?"))
                pbFadeOutIn(99999){
                   scene=PokemonBag_Scene.new
                   screen=PokemonBagScreen.new(scene,$PokemonBag)
                   berry=screen.pbChooseBerryScreen
                }
                if berry>0
                  timenow=pbGetTimeNow
                  berryData[0]=1             # growth stage (1-5)
                  berryData[1]=berry         # item ID of planted berry
                  berryData[2]=0             # seconds alive
                  berryData[3]=timenow.to_i  # time of last checkup (now)
                  berryData[4]=100           # dampness value
                  berryData[5]=0             # number of replants
                  berryData[6]=0             # yield penalty
                  $PokemonBag.pbDeleteItem(berry,1)
                  Kernel.pbMessage(_INTL("The {1} was planted in the soft, earthy soil.",
                     PBItems.getName(berry)))
                end
              end
              interp.setVariable(berryData)
            else
              Kernel.pbMessage(_INTL("That won't fertilize the soil!"))
            end
            return
          end
        elsif cmd==1 # Plant Berry
          pbFadeOutIn(99999){
             scene=PokemonBag_Scene.new
             screen=PokemonBagScreen.new(scene,$PokemonBag)
             berry=screen.pbChooseBerryScreen
          }
          if berry>0
            timenow=pbGetTimeNow
            berryData[0]=1             # growth stage (1-5)
            berryData[1]=berry         # item ID of planted berry
            berryData[2]=0             # seconds alive
            berryData[3]=timenow.to_i  # time of last checkup (now)
            berryData[4]=100           # dampness value
            berryData[5]=0             # number of replants
            berryData[6]=0             # yield penalty
            $PokemonBag.pbDeleteItem(berry,1)
            Kernel.pbMessage(_INTL("The {1} was planted in the soft, earthy soil.",
               PBItems.getName(berry)))
            interp.setVariable(berryData)
          end
          return
        end
      else
        Kernel.pbMessage(_INTL("{1} has been laid down.",PBItems.getName(berryData[7])))
        if Kernel.pbConfirmMessage(_INTL("Want to plant a Berry?"))
          pbFadeOutIn(99999){
             scene=PokemonBag_Scene.new
             screen=PokemonBagScreen.new(scene,$PokemonBag)
             berry=screen.pbChooseBerryScreen
          }
          if berry>0
            timenow=pbGetTimeNow
            berryData[0]=1             # growth stage (1-5)
            berryData[1]=berry         # item ID of planted berry
            berryData[2]=0             # seconds alive
            berryData[3]=timenow.to_i  # time of last checkup (now)
            berryData[4]=100           # dampness value
            berryData[5]=0             # number of replants
            berryData[6]=0             # yield penalty
            $PokemonBag.pbDeleteItem(berry,1)
            Kernel.pbMessage(_INTL("The {1} was planted in the soft, earthy soil.",
               PBItems.getName(berry)))
            interp.setVariable(berryData)
          end
          return
        end
      end
    else
      # Gen 3 planting mechanics
      if Kernel.pbConfirmMessage(_INTL("It's soft, loamy soil.\nPlant a berry?"))
        pbFadeOutIn(99999){
           scene=PokemonBag_Scene.new
           screen=PokemonBagScreen.new(scene,$PokemonBag)
           berry=screen.pbChooseBerryScreen
        }
        if berry>0
          timenow=pbGetTimeNow
          berryData[0]=1             # growth stage (1-5)
          berryData[1]=berry         # item ID of planted berry
          berryData[2]=false         # watered in this stage?
          berryData[3]=timenow.to_i  # time planted
          berryData[4]=0             # total waterings
          berryData[5]=0             # number of replants
          berryData[6]=nil; berryData[7]=nil; berryData.compact! # for compatibility
          $PokemonBag.pbDeleteItem(berry,1)
          Kernel.pbMessage(_INTL("{1} planted a {2} in the soft loamy soil.",
             $Trainer.name,PBItems.getName(berry)))
          interp.setVariable(berryData)
        end
        return
      end
    end
  when 1 # X planted
    Kernel.pbMessage(_INTL("A {1} was planted here.",PBItems.getName(berry)))
  when 2  # X sprouted
    Kernel.pbMessage(_INTL("The {1} has sprouted.",PBItems.getName(berry)))
  when 3  # X taller
    Kernel.pbMessage(_INTL("The {1} plant is growing bigger.",PBItems.getName(berry)))
  when 4  # X flowering
    if NEWBERRYPLANTS
      Kernel.pbMessage(_INTL("This {1} plant is in bloom!",PBItems.getName(berry)))
    else
      case berryData[4]
      when 4
        Kernel.pbMessage(_INTL("This {1} plant is in fabulous bloom!",PBItems.getName(berry)))
      when 3
        Kernel.pbMessage(_INTL("This {1} plant is blooming very beautifully!",PBItems.getName(berry)))
      when 2
        Kernel.pbMessage(_INTL("This {1} plant is blooming prettily!",PBItems.getName(berry)))
      when 1
        Kernel.pbMessage(_INTL("This {1} plant is blooming cutely!",PBItems.getName(berry)))
      else
        Kernel.pbMessage(_INTL("This {1} plant is in bloom!",PBItems.getName(berry)))
      end
    end
  when 5  # X berries
    berryvalues=$PokemonTemp.pbGetBerryPlantData(berryData[1])
    # Get berry yield (berrycount)
    berrycount=1
    if berryData.length>6
      # Gen 4 berry yield calculation
      berrycount=[berryvalues[3]-berryData[6],berryvalues[2]].max
    else
      # Gen 3 berry yield calculation
      if berryData[4]>0
        randomno=rand(1+berryvalues[3]-berryvalues[2])
        berrycount=(((berryvalues[3]-berryvalues[2])*(berryData[4]-1)+randomno)/4).floor+berryvalues[2]
      else
        berrycount=berryvalues[2]
      end
    end
    itemname=(berrycount>1) ? PBItems.getNamePlural(berry) : PBItems.getName(berry)
    if berrycount>1
      message=_INTL("There are {1} {2}!\nWant to pick them?",berrycount,itemname)
    else
      message=_INTL("There is 1 {1}!\nWant to pick it?",itemname)
    end
    if Kernel.pbConfirmMessage(message)
      if !$PokemonBag.pbCanStore?(berry,berrycount)
        Kernel.pbMessage(_INTL("Too bad...\nThe bag is full."))
        return
      end
      $PokemonBag.pbStoreItem(berry,berrycount)
      if berrycount>1
        Kernel.pbMessage(_INTL("You picked the {1} {2}.\\wtnp[30]",berrycount,itemname))
      else
        Kernel.pbMessage(_INTL("You picked the {1}.\\wtnp[30]",itemname))
      end
      Kernel.pbMessage(_INTL("{1} put away the {2} in the <icon=bagPocket#{BERRYPOCKET}>\\c[1]Berries\\c[0] Pocket.\1",
         $Trainer.name,itemname))
      if NEWBERRYPLANTS
        Kernel.pbMessage(_INTL("The soil returned to its soft and earthy state.\1"))
        berryData=[0,0,0,0,0,0,0,0]
      else
        Kernel.pbMessage(_INTL("The soil returned to its soft and loamy state.\1"))
        berryData=[0,0,false,0,0,0]
      end
      interp.setVariable(berryData)
    end
  end
  case berryData[0]
  when 1, 2, 3, 4
    for i in watering
      if i!=0 && $PokemonBag.pbQuantity(i)>0
        if Kernel.pbConfirmMessage(_INTL("Want to sprinkle some water with the {1}?",PBItems.getName(i)))
          if berryData.length>6
            # Gen 4 berry watering mechanics
            berryData[4]=100
          else
            # Gen 3 berry watering mechanics
            if berryData[2]==false
              berryData[4]+=1
              berryData[2]=true
            end
          end
          interp.setVariable(berryData)
          Kernel.pbMessage(_INTL("{1} watered the plant.\\wtnp[40]",$Trainer.name))
          if NEWBERRYPLANTS
            Kernel.pbMessage(_INTL("There! All happy!"))
          else
            Kernel.pbMessage(_INTL("The plant seemed to be delighted."))
          end
        end
        break
      end
    end
  end
end

def pbPickBerry(berry,qty=1)
  interp=pbMapInterpreter
  thisEvent=interp.get_character(0)
  berryData=interp.getVariable
  if berry.is_a?(String) || berry.is_a?(Symbol)
    berry=getID(PBItems,berry)
  end
  itemname=(qty>1) ? PBItems.getNamePlural(berry) : PBItems.getName(berry)
  if qty>1
    message=_INTL("There are {1} {2}!\nWant to pick them?",qty,itemname)
  else
    message=_INTL("There is 1 {1}!\nWant to pick it?",itemname)
  end
  if Kernel.pbConfirmMessage(message)
    if !$PokemonBag.pbCanStore?(berry,qty)
      Kernel.pbMessage(_INTL("Too bad...\nThe bag is full."))
      return
    end
    $PokemonBag.pbStoreItem(berry,qty)
    pocket=pbGetPocket(berry)
    if qty>1
      Kernel.pbMessage(_INTL("You picked the {1} {2}.\\wtnp[30]",qty,itemname))
    else
      Kernel.pbMessage(_INTL("You picked the {1}.\\wtnp[30]",itemname))
    end
    Kernel.pbMessage(_INTL("{1} put away the {2} in the <icon=bagPocket#{pocket}>\\c[1]Berries\\c[0] Pocket.\1",
       $Trainer.name,itemname))
    if NEWBERRYPLANTS
      Kernel.pbMessage(_INTL("The soil returned to its soft and earthy state.\1"))
      berryData=[0,0,0,0,0,0,0,0]
    else
      Kernel.pbMessage(_INTL("The soil returned to its soft and loamy state.\1"))
      berryData=[0,0,false,0,0,0]
    end
    interp.setVariable(berryData)
    pbSetSelfSwitch(thisEvent.id,"A",true)
  end
end