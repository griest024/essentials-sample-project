#===============================================================================
# Global metadata not specific to a map.  This class holds field state data that
# span multiple maps.
#===============================================================================
class PokemonGlobalMetadata
  attr_accessor :bicycle
  attr_accessor :surfing
  attr_accessor :diving
  attr_accessor :sliding
  attr_accessor :fishing
  attr_accessor :runtoggle
  attr_accessor :repel
  attr_accessor :flashUsed
  attr_accessor :bridge
  attr_accessor :runningShoes
  attr_accessor :snagMachine
  attr_accessor :seenStorageCreator
  attr_accessor :startTime
  attr_accessor :creditsPlayed
  attr_accessor :playerID
  attr_accessor :coins
  attr_accessor :sootsack
  attr_accessor :mailbox
  attr_accessor :pcItemStorage
  attr_accessor :stepcount
  attr_accessor :happinessSteps
  attr_accessor :pokerusTime
  attr_accessor :daycare
  attr_accessor :daycareEgg
  attr_accessor :daycareEggSteps
  attr_accessor :pokedexUnlocked # Array storing which Dexes are unlocked
  attr_accessor :pokedexViable   # All Dexes of non-zero length and unlocked
  attr_accessor :pokedexDex      # Dex currently looking at (-1 is National Dex)
  attr_accessor :pokedexIndex    # Last species viewed per Dex
  attr_accessor :pokedexMode     # Search mode
  attr_accessor :healingSpot
  attr_accessor :escapePoint
  attr_accessor :pokecenterMapId
  attr_accessor :pokecenterX
  attr_accessor :pokecenterY
  attr_accessor :pokecenterDirection
  attr_accessor :visitedMaps
  attr_accessor :mapTrail
  attr_accessor :nextBattleBGM
  attr_accessor :nextBattleME
  attr_accessor :nextBattleBack
  attr_accessor :safariState
  attr_accessor :bugContestState
  attr_accessor :partner
  attr_accessor :challenge
  attr_accessor :lastbattle
  attr_accessor :phoneNumbers
  attr_accessor :phoneTime
  attr_accessor :eventvars
  attr_accessor :safesave

  def initialize
    @bicycle              = false
    @surfing              = false
    @diving               = false
    @sliding              = false
    @fishing              = false
    @runtoggle            = false
    @repel                = 0
    @flashused            = false
    @bridge               = 0
    @runningShoes         = false
    @snagMachine          = false
    @seenStorageCreator   = false
    @startTime            = Time.now
    @creditsPlayed        = false
    @playerID             = -1
    @coins                = 0
    @sootsack             = 0
    @mailbox              = nil
    @pcItemStorage        = nil
    @stepcount            = 0
    @happinessSteps       = 0
    @pokerusTime          = nil
    @daycare              = [[nil,0],[nil,0]]
    @daycareEgg           = false
    @daycareEggSteps      = 0
    numRegions = 0
    pbRgssOpen("Data/regionals.dat","rb"){|f| numRegions = f.fgetw }
    @pokedexUnlocked      = []
    @pokedexViable        = []
    @pokedexDex           = (numRegions==0) ? -1 : 0
    @pokedexIndex         = []
    @pokedexMode          = 0
    for i in 0...numRegions+1     # National Dex isn't a region, but is included
      @pokedexIndex[i]    = 0
      @pokedexUnlocked[i] = (i==0)
    end
    @healingSpot          = nil
    @escapePoint          = []
    @pokecenterMapId      = -1
    @pokecenterX          = -1
    @pokecenterY          = -1
    @pokecenterDirection  = -1
    @visitedMaps          = []
    @mapTrail             = []
    @nextBattleBGM        = nil
    @nextBattleME         = nil
    @nextBattleBack       = nil
    @safariState          = nil
    @bugContestState      = nil
    @partner              = nil
    @challenge            = nil
    @lastbattle           = nil
    @phoneNumbers         = []
    @phoneTime            = 0
    @eventvars            = {}
    @safesave             = false
  end

  def bridge
    @bridge=0 if !@bridge
    return @bridge
  end
end



#===============================================================================
# This class keeps track of erased and moved events so their position
# can remain after a game is saved and loaded.  This class also includes
# variables that should remain valid only for the current map.
#===============================================================================
class PokemonMapMetadata
  attr_reader :erasedEvents
  attr_reader :movedEvents    
  attr_accessor :strengthUsed
  attr_accessor :blackFluteUsed
  attr_accessor :whiteFluteUsed

  def initialize
    clear
  end

  def clear
    @erasedEvents={}
    @movedEvents={}
    @strengthUsed=false
    @blackFluteUsed=false
    @whiteFluteUsed=false
  end

  def addErasedEvent(eventID)
    key=[$game_map.map_id,eventID]
    @erasedEvents[key]=true
  end

  def addMovedEvent(eventID)
    key=[$game_map.map_id,eventID]
    event=$game_map.events[eventID]
    @movedEvents[key]=[event.x,event.y,event.direction,event.through]
  end

  def updateMap
    for i in @erasedEvents
      if i[0][0]==$game_map.map_id && i[1]
        event=$game_map.events[i[0][1]]
        event.erase if event
      end
    end
    for i in @movedEvents
      if i[0][0]==$game_map.map_id && i[1]
        next if !$game_map.events[i[0][1]]
        $game_map.events[i[0][1]].moveto(i[1][0],i[1][1])
        case i[1][2]
        when 2
          $game_map.events[i[0][1]].turn_down
        when 4
          $game_map.events[i[0][1]].turn_left
        when 6
          $game_map.events[i[0][1]].turn_right
        when 8
          $game_map.events[i[0][1]].turn_up
        end
      end
      if i[1][3]!=nil
        $game_map.events[i[0][1]].through=i[1][3]
      end
    end
  end
end



#===============================================================================
# Temporary data which is not saved and which is erased when a game restarts.
#===============================================================================
class PokemonTemp
  attr_accessor :menuLastChoice
  attr_accessor :keyItemCalling
  attr_accessor :hiddenMoveEventCalling
  attr_accessor :begunNewGame
  attr_accessor :miniupdate
  attr_accessor :waitingTrainer
  attr_accessor :darknessSprite
  attr_accessor :pokemonDexData
  attr_accessor :pokemonMetadata
  attr_accessor :pokemonPhoneData
  attr_accessor :lastbattle
  attr_accessor :flydata

  def initialize
    @menuLastChoice         = 0
    @keyItemCalling         = false
    @hiddenMoveEventCalling = false
    @begunNewGame           = false
    @miniupdate             = false
    @waitingTrainer         = nil
    @darknessSprite         = nil
    @pokemonDexData         = nil
    @pokemonMetadata        = nil
    @pokemonPhoneData       = nil
    @lastbattle             = nil
    @flydata                = nil
  end
end