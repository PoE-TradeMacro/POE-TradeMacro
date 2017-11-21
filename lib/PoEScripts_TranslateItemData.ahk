﻿PoEScripts_TranslateItemData(data, langData, locale, ByRef status = "") {
	If (not StrLen(locale) or locale = "en") {
		status := "Translation aborted"
		Return data
	}
					; ["de", "fr", "pt", "ru", "th", "es"]
	rarityTags		:= ["Seltenheit", "Rareté", "Raridade", "Редкость", "ความหายาก", "Rareza"]	; hardcoded, no reliable translation source
	rareTranslation	:= ["Selten", "Rare", "Raro", "Редкий", "แรร์", "Raro"]		; hardcoded, at least the german term for "rare" is "wrong" and differently translated elsewhere
	superiorTag		:= ["(hochwertig)", "de qualité", "Superior", "качества", "Superior", "Superior"]
	regex 			:= {}
	regex.superior		:= ["(.*)\(hochwertig\)$", "(.*)de qualité$", "(.*)Superior$", "(.*)качества$", "^Superior(.*)", "(.*)Superior$"]
	regex.map			:= ["Karte.*'(.*)'", "Carte:(.*)","Mapa:(.*)", "Карта(.*)", "(.*)Map", "Mapa de(.*)"]
	
	lang := new TranslationHelpers(langData, regex)
	
	;---- Not every item has every section,  depending on BaseType and Corruption/Enchantment
	; Section01 = NamePlate (Rarity, ItemName, ItemBaseType)
	; Section02 = Armour/Weapon innate stats like EV, ES, AR, Quality, PhysDmg, EleDmg, APs, CritChance AND Flask Charges/Duration etc
	; Section03 = Requirements (dex, int, str, level)
	; Section04 = Implicit Mod / Enchantment
	; Section05 = Explicit Mods
	; Section06 = Corruption tag
	; Section07+ = Descriptions/Flavour Texts
	
	; push all sections to array
	sections	:= []
	sectionsT := []
	Pos		:= 0
	_data := data "--------"
	
	While Pos := RegExMatch(_data, "is)(.*?)(\r\n-{8})", section, Pos + (StrLen(section) ? StrLen(section) : 1)) {
		sectionLines := []
		Loop, parse, section1, `n, `r 
		{			
			If (StrLen(Trim(A_LoopField))) {
				sectionLines.push(Trim(A_LoopField))
			}
		}
		sections.push(sectionLines)
	}
	
	_specialTypes := ["Currency", "Divination Card"]
	_ItemBaseType := ""
	_item := {}
	
	For key, section in sections {
		sectionsT[key] := []
		
		/*
			nameplate section, look for ItemBaseType which is important for further parsing.
		*/
		If (key = 1) {
			/*
				rarity
			*/
			RegExMatch(section[1], "i)(.*?):(.*)", keyValuePair)
			If (lang.IsInArray(keyValuePair1, rarityTags, posFound)) {
				_item.default_rarity:= lang.GetBasicInfo(Trim(keyValuePair2))
				_item.local_rarity	:= Trim(keyValuePair2)			
				
				; TODO: improve this, only works for "rare", not sure if needed
				If (not _item.default_rarity) {
					_item.default_rarity := lang.GetBasicInfo(rareTranslation[posFound])						
				}				
				sectionsT[key][1] := "Rarity: " _item.default_rarity
			}
			
			/*
				name and basetype
			*/
			sectionLength := section.MaxIndex()
			; remove "superior" when using name as search needle
			needleName := Trim(RegExReplace(section[2], "" regex.superior[posFound] "", "$1", replacedSuperiorTag))			
			
			_obj := lang.GetItemInfo(section[3], needleName, _item.default_rarity, _item.rarityLocal)
			sectionsT[key][2] := _obj.default_name ? _obj.default_name : Trim(section[2])
			If (replacedSuperiorTag) {
				sectionsT[key][2] := "Superior " sectionsT[key][2]
			}
			
			sectionsT[key][3] := _obj.default_baseType ? _obj.default_baseType : Trim(section[3])
			lang.AddPropertiesToObj(_item, _obj)
			
			; don't set third line if name and baseType are the same (currency, cards etc)
			If (_item.default_name == _item.default_baseType or RegExMatch(_item.default_baseType, "" regex.map[posFound] "")) {			
				sectionsT[key][3] := ""
			}
			
			_ItemBaseType := sectionsT[key][3]
		}
		
		
		
		; 
		
		debugprintarray([sectionsT, _item])
		break
	}

	Return data
}

class TranslationHelpers {
	__New(dataObj, regExObj)
	{
		this.data	:= dataObj
		this.regEx := regExObj
	}
	
	GetBasicInfo(needle, reverse = false) {
		basic := this.data.localized.basic

		For key, val in basic {
			If (not reverse) {
				If (needle = val.localized and StrLen(needle)) {
					Return val.default
				}	
			}
			Else {
				If (needle = val.default and StrLen(needle)) {
					Return val.localized
				}				
			}
		}
	}
	
	GetItemInfo(needleType, needleName = "", needleRarity = "", needleRarityLocal = "") {
		localized	:= this.data.localized.items
		default 	:= this.data.default.items
		
		local	:= this.data.localized.static
		def	 	:= this.data.default.static	

		_arr := {}
		found := false
		Loop, % localized.MaxIndex() {
			i := A_Index
			For key, val in localized[i] {			
				label := localized[i].label
				If (key = "entries") {
					For k, v in val {						
						; currency, gems, cards and other similiar items use their name as type 
						If (not StrLen(needleType)) {
							foundType := v.type = Trim(needleName) and Strlen(v.type) ? true : false
						} Else {							
							foundType := v.type = Trim(needleType) and Strlen(v.type) ? true : false
						}
						foundName := v.name = Trim(needleName) and Strlen(v.name) ? true : false
						
						If (foundName and foundType) {
							_arr.local_name		:= v.name
							_arr.lcoal_baseType		:= v.type
							_arr.local_type		:= label
							_arr.default_name		:= default[i][key][k].name
							_arr.default_baseType	:= default[i][key][k].type
							_arr.default_type		:= default[i].label
							
							found := true
							Break
						}
						Else If (foundType) {
							_arr.local_name		:= needleName
							_arr.local_baseType		:= v.type
							_arr.local_type		:= label
							_arr.default_baseType	:= default[i][key][k].type
							_arr.default_type		:= default[i].label
							If (not StrLen(needleType)) {
								_arr.default_name	:= default[i][key][k].type
							}
							
							found := true
							Break
						}
					}
				}
				If (found) {
					Break
				}
			}
			If (found) {
				Break
			}
		}	

		; backup check for static items (div cards, currency, maps, leaguestones, fragments, essences etc)
		If (not found) {			
			id := ""
			index := ""
			
			For k, v in local {
				For key, val in local[k] {
					If (val.text = needleName or val.text = needleType) {
						id := val.id
						index := k
						Break
					}
				}	
			}			

			For key, val in def[index] {				
				If (val.id = id) {
					_arr.local_name		:= needleName					
					_arr.default_name		:= val.text
					
					If (RegExMatch(index, "i)maps")) {
						_arr.local_baseType		:= needleName				
						_arr.local_type		:= RegExReplace(needleName, "" this.regEx.map "", "$1")
						_arr.default_baseType	:= val.text
						_arr.default_type		:= "Map"
					} Else {
						_arr.local_baseType		:= ""
						_arr.local_type		:= needleRarityLocal
						_arr.default_baseType	:= ""
						_arr.default_type		:= needleRarity
					}
					found := true
					Break					
				}
				If (found) {
					Break
				}
			}
			
			; TODO: test leaguestones
		}
		
		; replace the type with it's singular form
		typePlural	:= ["Weapons", "Armour", "Accessories", "Gems", "Jewels", "Flasks", "Maps", "Leaguestones", "Prophecies", "Cards", "Currency"]
		typeSingular	:= ["Weapon", "Armour", "Accessory", "Gem", "Jewel", "Flask", "Map", "Leaguestone", "Prophecy", "Card", "Currency"]		
		_arr.default_type := (replaced := this.IsInArray(_arr.default_type, typePlural, posFound)) ? typeSingular[posFound] : _arr.default_type
		
		If (replaced) {			
			_arr.local_type := (StrLen(_tempType := this.GetBasicInfo(_arr.default_type, true))) ? _tempType : _arr.local_type
		}		
		;debugprintarray(_arr)
		
		Return _arr
	}
	
	AddPropertiesToObj(ByRef target, source) {
		For key, val in source {
			target[key] := val
		}
	}
	
	IsArray(obj) {
		Return !!obj.MaxIndex()
	}

	; Trim trailing zeros from numbers
	ZeroTrim(number) {
		RegExMatch(number, "(\d+)\.?(.+)?", match)
		If (StrLen(match2) < 1) {
			Return number
		} Else {
			trail := RegExReplace(match2, "0+$", "")
			number := (StrLen(trail) > 0) ? match1 "." trail : match1
			Return number
		}
	}

	IsInArray(el, array, ByRef i) {
		For i, element in array {
			If (el = "") {
				Return false
			}
			If (element = el) {
				Return true
			}
		}
		Return false
	}

	CleanUp(in) {
		StringReplace, in, in, `n,, All
		StringReplace, in, in, `r,, All
		Return Trim(in)
	}


	Arr_concatenate(p*) {
		res := Object()
		For each, obj in p
			For each, value in obj
				res.Insert(value)
		return res
	}
}