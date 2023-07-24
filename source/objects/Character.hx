package objects;

import flixel.graphics.frames.FlxFramesCollection;
import flixel.animation.FlxAnimationController;
import animateatlas.AtlasFrameMaker;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.effects.FlxTrail;
import flixel.animation.FlxBaseAnimation;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.tweens.FlxTween;
import flixel.util.FlxSort;
import backend.Section.SwagSection;
import backend.Song;
import states.stages.objects.TankmenBG;
#if MODS_ALLOWED
import sys.io.File;
import sys.FileSystem;
#end
import openfl.utils.AssetType;
import openfl.utils.Assets;
import tjson.TJSON as Json;

using StringTools;

typedef CharacterFile = {
	var animations:Array<AnimArray>;
	var image:String;
	var scale:Float;
	var sing_duration:Float;
	var healthicon:String;

	var position:Array<Float>;
	var camera_position:Array<Float>;

	var flip_x:Bool;
	var no_antialiasing:Bool;
	var healthbar_colors:Array<Int>;
}

typedef AnimArray = {
	var anim:String;
	var name:String;
	var fps:Int;
	var loop:Bool;
	var indices:Array<Int>;
	var offsets:Array<Int>;
	var image:String;
}

class Character extends FlxSprite
{
	public var animOffsets:Map<String, Array<Dynamic>>;
	public var debugMode:Bool = false;

	// For swapping out huge sheets
	public var framesList:Map<String, FlxFramesCollection>; // Image, Frames
	public var imageNames:Map<String, String>; // Anim Name, Image
	public var animStates:Map<String, FlxAnimationController>; // Image, Anim Controller
	public var curFrames:String; // Current image name
	public static var tempAnimState:FlxAnimationController; // Just so that the real one won't be cleared (It crashes if it's null)

	public var useAtlas:Bool;

	public var isPlayer:Bool = false;
	public var curCharacter:String = DEFAULT_CHARACTER;

	public var colorTween:FlxTween;
	public var holdTimer:Float = 0;
	public var heyTimer:Float = 0;
	public var specialAnim:Bool = false;
	public var animationNotes:Array<Dynamic> = [];
	public var stunned:Bool = false;
	public var singDuration:Float = 4; // Multiplier of how long a character holds the sing pose
	public var idleSuffix:String = '';
	public var danceIdle:Bool = false; // Character uses "danceLeft" and "danceRight" instead of "idle"
	public var skipDance:Bool = false;

	public var healthIcon:String = 'face';
	public var animationsArray:Array<AnimArray> = [];

	public var positionArray:Array<Float> = [0, 0];
	public var cameraPosition:Array<Float> = [0, 0];

	public var hasMissAnimations:Bool = false;

	//Used on Character Editor
	public var imageFile:String = '';
	public var jsonScale:Float = 1;
	public var noAntialiasing:Bool = false;
	public var originalFlipX:Bool = false;
	public var healthColorArray:Array<Int> = [255, 0, 0];

	public static var DEFAULT_CHARACTER:String = 'bf'; //In case a character is missing, it will use BF on its place
	public function new(x:Float, y:Float, ?character:String = 'none', ?isPlayer:Bool = false)
	{
		super(x, y);

		#if (haxe >= "4.0.0")
		animOffsets = new Map();
		framesList = new Map();
		imageNames = new Map();
		animStates = new Map();
		#else
		animOffsets = new Map<String, Array<Dynamic>>();
		framesList = new Map<String, FlxFramesCollection>();
		imageNames = new Map<String, String>();
		animStates = new Map<String, FlxAnimationController>();
		#end
		if (tempAnimState != null) {
			tempAnimState.destroy();
		}
		tempAnimState = new FlxAnimationController(this);
		curCharacter = character;
		this.isPlayer = isPlayer;
		var library:String = null;
		switch (curCharacter)
		{
			//case 'your character name in case you want to hardcode them instead':

			default:
				var characterPath:String = 'characters/' + curCharacter + '.json';

				#if MODS_ALLOWED
				var path:String = Paths.modFolders(characterPath);
				if (!FileSystem.exists(path)) {
					path = Paths.getPreloadPath(characterPath);
				}

				if (!FileSystem.exists(path))
				#else
				var path:String = Paths.getPreloadPath(characterPath);
				if (!Assets.exists(path))
				#end
				{
					path = Paths.getPreloadPath('characters/' + DEFAULT_CHARACTER + '.json'); //If a character couldn't be found, change him to BF just to prevent a crash
				}

				#if MODS_ALLOWED
				var rawJson = File.getContent(path);
				#else
				var rawJson = Assets.getText(path);
				#end

				var json:CharacterFile = cast Json.parse(rawJson);
				useAtlas = false;
				
				#if MODS_ALLOWED
				var modAnimToFind:String = Paths.modFolders('images/' + json.image + '/Animation.json');
				var animToFind:String = Paths.getPath('images/' + json.image + '/Animation.json', TEXT);
				
				if (FileSystem.exists(modAnimToFind) || FileSystem.exists(animToFind) || Assets.exists(animToFind))
				#else
				if (Assets.exists(Paths.getPath('images/' + json.image + '/Animation.json', TEXT)))
				#end
					useAtlas = true;

				if (!useAtlas) {
					frames = Paths.getAtlas(json.image);
					curFrames = json.image;
					framesList.set(json.image, frames);
					animStates.set(json.image, animation);
					for (anim in json.animations) {
						if (anim.image != null && anim.image.length > 0 && !framesList.exists(anim.image)) {
							framesList.set(anim.image, Paths.getAtlas(anim.image));
							animStates.set(anim.image, new FlxAnimationController(this));
						}
						else if (anim.image == null)
							anim.image = '';
						imageNames.set(anim.anim, anim.image);
					}
				}
				else {
					frames = AtlasFrameMaker.construct(json.image);
					curFrames = json.image;
					framesList.set(json.image, frames);
					animStates.set(json.image, animation);
					for (anim in json.animations) {
						if (anim.image != null && anim.image.length > 0 && !framesList.exists(anim.image)) {
							framesList.set(anim.image, AtlasFrameMaker.construct(anim.image));
							animStates.set(anim.image, new FlxAnimationController(this));
						}
						else if (anim.image == null)
							anim.image = '';
						imageNames.set(anim.anim, anim.image);
					}
				}
				imageFile = json.image;

				if(json.scale != 1) {
					jsonScale = json.scale;
					setGraphicSize(Std.int(width * jsonScale));
					updateHitbox();
				}

				// positioning
				positionArray = json.position;
				cameraPosition = json.camera_position;

				// data
				healthIcon = json.healthicon;
				singDuration = json.sing_duration;
				flipX = (json.flip_x == true);

				if(json.healthbar_colors != null && json.healthbar_colors.length > 2)
					healthColorArray = json.healthbar_colors;

				// antialiasing
				noAntialiasing = (json.no_antialiasing == true);
				antialiasing = ClientPrefs.data.antialiasing ? !noAntialiasing : false;

				// animations
				animationsArray = json.animations;
				if(animationsArray != null && animationsArray.length > 0) {
					for (anim in animationsArray) {
						var animAnim:String = '' + anim.anim;
						var animName:String = '' + anim.name;
						var animFps:Int = anim.fps;
						var animLoop:Bool = !!anim.loop; // Bruh
						var animIndices:Array<Int> = anim.indices;
						var animImage:String = anim.image;

						if (animImage == null || animImage.length == 0) {
							animImage = imageFile;
						}
						if (animImage != curFrames) {
							//trace(animImage + ', ' + curFrames);
							animation = tempAnimState;
							frames = framesList.get(animImage);
							animation = animStates.get(animImage);
							curFrames = animImage;
						}

						if (animIndices != null && animIndices.length > 0) {
							animation.addByIndices(animAnim, animName, animIndices, "", animFps, animLoop);
						} else {
							animation.addByPrefix(animAnim, animName, animFps, animLoop);
						}

						if(anim.offsets != null && anim.offsets.length > 1) {
							addOffset(anim.anim, anim.offsets[0], anim.offsets[1]);
						}
					}
				} else {
					quickAnimAdd('idle', 'BF idle dance');
				}
				animation = tempAnimState;
				frames = framesList.get(json.image);
				animation = animStates.get(json.image);
				curFrames = json.image;
				//trace('Loaded file to character ' + curCharacter);
		}
		originalFlipX = flipX;

		if(animOffsets.exists('singLEFTmiss') || animOffsets.exists('singDOWNmiss') || animOffsets.exists('singUPmiss') || animOffsets.exists('singRIGHTmiss')) hasMissAnimations = true;
		recalculateDanceIdle();
		dance();

		if (isPlayer)
		{
			flipX = !flipX;

			/*// Doesn't flip for BF, since his are already in the right place???
			if (!curCharacter.startsWith('bf'))
			{
				// var animArray
				if(animation.getByName('singLEFT') != null && animation.getByName('singRIGHT') != null)
				{
					var oldRight = animation.getByName('singRIGHT').frames;
					animation.getByName('singRIGHT').frames = animation.getByName('singLEFT').frames;
					animation.getByName('singLEFT').frames = oldRight;
				}

				// IF THEY HAVE MISS ANIMATIONS??
				if (animation.getByName('singLEFTmiss') != null && animation.getByName('singRIGHTmiss') != null)
				{
					var oldMiss = animation.getByName('singRIGHTmiss').frames;
					animation.getByName('singRIGHTmiss').frames = animation.getByName('singLEFTmiss').frames;
					animation.getByName('singLEFTmiss').frames = oldMiss;
				}
			}*/
		}

		switch(curCharacter)
		{
			case 'pico-speaker':
				skipDance = true;
				loadMappedAnims();
				playAnim("shoot1");
		}
	}

	override function update(elapsed:Float)
	{
		if (!debugMode && animation.curAnim != null) {
			if (animation.curAnim.finished && imageNames.exists(animation.curAnim.name + '-loop')) {
				var special = specialAnim;
				playAnim(animation.curAnim.name + '-loop');
				specialAnim = special;
			}

			if (heyTimer > 0) {
				heyTimer -= elapsed * PlayState.instance.playbackRate;
				if (heyTimer <= 0) {
					if (specialAnim && animation.curAnim.name == 'hey' || animation.curAnim.name == 'cheer') {
						specialAnim = false;
						dance();
					}
					heyTimer = 0;
				}
			}
			else if (specialAnim && animation.curAnim.finished) {
				specialAnim = false;
				dance();
			}
			
			switch(curCharacter) {
				case 'pico-speaker':
					if (animationNotes.length > 0 && Conductor.songPosition > animationNotes[0][0]) {
						var noteData:Int = 1;
						if (animationNotes[0][1] > 2) noteData = 3;

						noteData += FlxG.random.int(0, 1);
						playAnim('shoot' + noteData, true);
						animationNotes.shift();
					}
					if (animation.curAnim.finished) playAnim(animation.curAnim.name, false, false, animation.curAnim.frames.length - 3);
			}

			if (animation.curAnim.name.startsWith('sing'))
				holdTimer += elapsed;
			else if (isPlayer)
				holdTimer = 0;

			if (!isPlayer && holdTimer >= Conductor.stepCrochet * (0.0011 / (FlxG.sound.music != null ? FlxG.sound.music.pitch : 1)) * singDuration)
			{
				var anim:String = animation.curAnim.name;
				if (anim.endsWith('-loop'))
					anim = anim.substr(0, anim.length - 5);

				if (animOffsets.exists(anim + '-release')) {
					playAnim(anim + '-release');
					var oldCallback = animation.finishCallback;
					animation.finishCallback = function(name:String) {
						if (animation.curAnim != null && animation.curAnim.name == anim + '-release')
							dance();
						animation.finishCallback = oldCallback;
					}
				}
				else
					dance();

				holdTimer = 0;
			}
		}
		super.update(elapsed);
	}

	public var danced:Bool = false;

	/**
	 * FOR GF DANCING SHIT
	 */
	public function dance()
	{
		if (!debugMode && !skipDance && !specialAnim)
		{
			if(danceIdle)
			{
				danced = !danced;

				if (danced)
					playAnim('danceRight' + idleSuffix);
				else
					playAnim('danceLeft' + idleSuffix);
			}
			else if(animation.getByName('idle' + idleSuffix) != null) {
					playAnim('idle' + idleSuffix);
			}
		}
	}

	public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0):Void
	{
		var prevFrames = imageNames.get(AnimName);
		if (prevFrames == null || prevFrames.length == 0) {
			prevFrames = imageFile;
		}
		if (prevFrames != null && prevFrames != curFrames) {
			animation = tempAnimState;
			frames = framesList.get(prevFrames);
			animation = animStates.get(prevFrames);
			curFrames = prevFrames;
		}

		specialAnim = false;
		animation.play(AnimName, Force, Reversed, Frame);

		var daOffset = animOffsets.get(AnimName);
		if (animOffsets.exists(AnimName))
		{
			offset.set(daOffset[0], daOffset[1]);
		}
		else
			offset.set(0, 0);

		if (curCharacter.startsWith('gf'))
		{
			if (AnimName == 'singLEFT')
			{
				danced = true;
			}
			else if (AnimName == 'singRIGHT')
			{
				danced = false;
			}

			if (AnimName == 'singUP' || AnimName == 'singDOWN')
			{
				danced = !danced;
			}
		}
	}
	
	function loadMappedAnims():Void
	{
		var noteData:Array<SwagSection> = Song.loadFromJson('picospeaker', Paths.formatToSongPath(PlayState.SONG.song)).notes;
		for (section in noteData) {
			for (songNotes in section.sectionNotes) {
				animationNotes.push(songNotes);
			}
		}
		TankmenBG.animationNotes = animationNotes;
		animationNotes.sort(sortAnims);
	}

	function sortAnims(Obj1:Array<Dynamic>, Obj2:Array<Dynamic>):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1[0], Obj2[0]);
	}

	public var danceEveryNumBeats:Int = 2;
	private var settingCharacterUp:Bool = true;
	public function recalculateDanceIdle() {
		var lastDanceIdle:Bool = danceIdle;
		danceIdle = (animation.getByName('danceLeft' + idleSuffix) != null && animation.getByName('danceRight' + idleSuffix) != null);

		if(settingCharacterUp)
		{
			danceEveryNumBeats = (danceIdle ? 1 : 2);
		}
		else if(lastDanceIdle != danceIdle)
		{
			var calc:Float = danceEveryNumBeats;
			if(danceIdle)
				calc /= 2;
			else
				calc *= 2;

			danceEveryNumBeats = Math.round(Math.max(calc, 1));
		}
		settingCharacterUp = false;
	}

	public function addOffset(name:String, x:Float = 0, y:Float = 0)
	{
		animOffsets[name] = [x, y];
	}

	public function quickAnimAdd(name:String, anim:String)
	{
		animation.addByPrefix(name, anim, 24, false);
	}
}
