Red [
	Title:   "Information extractor from Red runtime source code"
	Author:  "Nenad Rakocevic"
	File: 	 %extractor.r
	Tabs:	 4
	Rights:  "Copyright (C) 2011-2018 Red Foundation. All rights reserved."
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
	Notes: {
		These utility functions extract types ID and function definitions from Red
		runtime source code and make it available to the compiler, before the Red runtime
		is actually compiled.
		
		This procedure is required during bootstrapping, as the REBOL compiler can't
		examine loaded Red data in memory at runtime.
	}
]

context [
	definitions: [
	    TYPE_VALUE 0 
	    TYPE_DATATYPE 1 
	    TYPE_UNSET 2 
	    TYPE_NONE 3 
	    TYPE_LOGIC 4 
	    TYPE_BLOCK 5 
	    TYPE_PAREN 6 
	    TYPE_STRING 7 
	    TYPE_FILE 8 
	    TYPE_URL 9 
	    TYPE_CHAR 10 
	    TYPE_INTEGER 11 
	    TYPE_FLOAT 12 
	    TYPE_SYMBOL 13 
	    TYPE_CONTEXT 14 
	    TYPE_WORD 15 
	    TYPE_SET_WORD 16 
	    TYPE_LIT_WORD 17 
	    TYPE_GET_WORD 18 
	    TYPE_REFINEMENT 19 
	    TYPE_ISSUE 20 
	    TYPE_NATIVE 21 
	    TYPE_ACTION 22 
	    TYPE_OP 23 
	    TYPE_FUNCTION 24 
	    TYPE_PATH 25 
	    TYPE_LIT_PATH 26 
	    TYPE_SET_PATH 27 
	    TYPE_GET_PATH 28 
	    TYPE_ROUTINE 29 
	    TYPE_BITSET 30 
	    TYPE_TRIPLE 31 
	    TYPE_OBJECT 32 
	    TYPE_TYPESET 33 
	    TYPE_ERROR 34 
	    TYPE_VECTOR 35 
	    TYPE_HASH 36 
	    TYPE_PAIR 37 
	    TYPE_PERCENT 38 
	    TYPE_TUPLE 39 
	    TYPE_MAP 40 
	    TYPE_BINARY 41 
	    TYPE_SERIES 42 
	    TYPE_TIME 43 
	    TYPE_TAG 44 
	    TYPE_EMAIL 45 
	    TYPE_HANDLE 46 
	    TYPE_DATE 47 
	    TYPE_PORT 48 
	    TYPE_MONEY 49 
	    TYPE_REF 50 
	    TYPE_POINT2D 51 
	    TYPE_POINT3D 52 
	    TYPE_IMAGE 53 
	    TYPE_EVENT 54 
	    TYPE_CLOSURE 55 
	    TYPE_SLICE 56 
	    TYPE_TOTAL_COUNT 57 
	    ACT_MAKE 1 
	    ACT_RANDOM 2 
	    ACT_REFLECT 3 
	    ACT_TO 4 
	    ACT_FORM 5 
	    ACT_MOLD 6 
	    ACT_EVALPATH 7 
	    ACT_SETPATH 8 
	    ACT_COMPARE 9 
	    ACT_ABSOLUTE 10 
	    ACT_ADD 11 
	    ACT_DIVIDE 12 
	    ACT_MULTIPLY 13 
	    ACT_NEGATE 14 
	    ACT_POWER 15 
	    ACT_REMAINDER 16 
	    ACT_ROUND 17 
	    ACT_SUBTRACT 18 
	    ACT_EVEN? 19 
	    ACT_ODD? 20 
	    ACT_AND~ 21 
	    ACT_COMPLEMENT 22 
	    ACT_OR~ 23 
	    ACT_XOR~ 24 
	    ACT_APPEND 25 
	    ACT_AT 26 
	    ACT_BACK 27 
	    ACT_CHANGE 28 
	    ACT_CLEAR 29 
	    ACT_COPY 30 
	    ACT_FIND 31 
	    ACT_HEAD 32 
	    ACT_HEAD? 33 
	    ACT_INDEX? 34 
	    ACT_INSERT 35 
	    ACT_LENGTH? 36 
	    ACT_MOVE 37 
	    ACT_NEXT 38 
	    ACT_PICK 39 
	    ACT_POKE 40 
	    ACT_PUT 41 
	    ACT_REMOVE 42 
	    ACT_REVERSE 43 
	    ACT_SELECT 44 
	    ACT_SORT 45 
	    ACT_SKIP 46 
	    ACT_SWAP 47 
	    ACT_TAIL 48 
	    ACT_TAIL? 49 
	    ACT_TAKE 50 
	    ACT_TRIM 51 
	    ACT_CREATE 52 
	    ACT_CLOSE 53 
	    ACT_DELETE 54 
	    ACT_MODIFY 55 
	    ACT_OPEN 56 
	    ACT_OPEN? 57 
	    ACT_QUERY 58 
	    ACT_READ 59 
	    ACT_RENAME 60 
	    ACT_UPDATE 61 
	    ACT_WRITE 62 
	    NAT_IF 1 
	    NAT_UNLESS 2 
	    NAT_EITHER 3 
	    NAT_ANY 4 
	    NAT_ALL 5 
	    NAT_WHILE 6 
	    NAT_UNTIL 7 
	    NAT_LOOP 8 
	    NAT_REPEAT 9 
	    NAT_FOREVER 10 
	    NAT_FOREACH 11 
	    NAT_FORALL 12 
	    NAT_REMOVE_EACH 13 
	    NAT_FUNC 14 
	    NAT_FUNCTION 15 
	    NAT_DOES 16 
	    NAT_HAS 17 
	    NAT_SWITCH 18 
	    NAT_CASE 19 
	    NAT_DO 20 
	    NAT_GET 21 
	    NAT_SET 22 
	    NAT_PRINT 23 
	    NAT_PRIN 24 
	    NAT_EQUAL? 25 
	    NAT_NOT_EQUAL? 26 
	    NAT_STRICT_EQUAL? 27 
	    NAT_LESSER? 28 
	    NAT_GREATER? 29 
	    NAT_LESSER_OR_EQUAL? 30 
	    NAT_GREATER_OR_EQUAL? 31 
	    NAT_SAME? 32 
	    NAT_NOT 33 
	    NAT_TYPE? 34 
	    NAT_REDUCE 35 
	    NAT_COMPOSE 36 
	    NAT_STATS 37 
	    NAT_BIND 38 
	    NAT_IN 39 
	    NAT_PARSE 40 
	    NAT_UNION 41 
	    NAT_INTERSECT 42 
	    NAT_UNIQUE 43 
	    NAT_DIFFERENCE 44 
	    NAT_EXCLUDE 45 
	    NAT_COMPLEMENT? 46 
	    NAT_DEHEX 47 
	    NAT_ENHEX 48 
	    NAT_NEGATIVE? 49 
	    NAT_POSITIVE? 50 
	    NAT_MAX 51 
	    NAT_MIN 52 
	    NAT_SHIFT 53 
	    NAT_TO_HEX 54 
	    NAT_SINE 55 
	    NAT_COSINE 56 
	    NAT_TANGENT 57 
	    NAT_ARCSINE 58 
	    NAT_ARCCOSINE 59 
	    NAT_ARCTANGENT 60 
	    NAT_ARCTANGENT2 61 
	    NAT_NAN? 62 
	    NAT_LOG_2 63 
	    NAT_LOG_10 64 
	    NAT_LOG_E 65 
	    NAT_EXP 66 
	    NAT_SQUARE_ROOT 67 
	    NAT_CONSTRUCT 68 
	    NAT_VALUE? 69 
	    NAT_TRY 70 
	    NAT_UPPERCASE 71 
	    NAT_LOWERCASE 72 
	    NAT_AS_PAIR 73 
	    NAT_AS_POINT2D 74 
	    NAT_AS_POINT3D 75 
	    NAT_AS_MONEY 76 
	    NAT_BREAK 77 
	    NAT_CONTINUE 78 
	    NAT_EXIT 79 
	    NAT_RETURN 80 
	    NAT_THROW 81 
	    NAT_CATCH 82 
	    NAT_EXTEND 83 
	    NAT_DEBASE 84 
	    NAT_TO_LOCAL_FILE 85 
	    NAT_WAIT 86 
	    NAT_CHECKSUM 87 
	    NAT_UNSET 88 
	    NAT_NEW_LINE 89 
	    NAT_NEW_LINE? 90 
	    NAT_ENBASE 91 
	    NAT_CONTEXT? 92 
	    NAT_SET_ENV 93 
	    NAT_GET_ENV 94 
	    NAT_LIST_ENV 95 
	    NAT_NOW 96 
	    NAT_SIGN? 97 
	    NAT_AS 98 
	    NAT_CALL 99 
	    NAT_ZERO? 100 
	    NAT_SIZE? 101 
	    NAT_BROWSE 102 
	    NAT_COMPRESS 103 
	    NAT_DECOMPRESS 104 
	    NAT_RECYCLE 105 
	    NAT_TRANSCODE 106 
	    NAT_APPLY 107
	]
	scalars: make object! [
	    internal!: [unset!]
	    external!: []
	    number!: [integer! float! percent!]
	    any-point!: [point2D! point3D!]
	    scalar!: [integer! float! percent! point2D! point3D! money! char! pair! tuple! time! date!]
	    any-word!: [word! set-word! get-word! lit-word!]
	    all-word!: [word! set-word! get-word! lit-word! refinement! issue!]
	    any-list!: [block! paren! hash!]
	    any-path!: [path! set-path! get-path! lit-path!]
	    any-block!: [path! set-path! get-path! lit-path! block! paren! hash!]
	    any-function!: [native! action! op! function! routine!]
	    any-object!: [object! error! port!]
	    any-string!: [string! file! url! tag! email! ref!]
	    series!: [binary! image! vector! path! set-path! get-path! lit-path! block! paren! hash! string! file! url! tag! email! ref!]
	    immediate!: [integer! float! percent! point2D! point3D! money! char! pair! tuple! time! date! word! set-word! get-word! lit-word! refinement! issue! none! logic! datatype! typeset! handle!]
	    default!: [binary! image! vector! path! set-path! get-path! lit-path! block! paren! hash! string! file! url! tag! email! ref! integer! float! percent! point2D! point3D! money! char! pair! tuple! time! date! word! set-word! get-word! lit-word! refinement! issue! none! logic! datatype! typeset! handle! object! error! port! native! action! op! function! routine! map! bitset!]
	    any-type!: [binary! image! vector! path! set-path! get-path! lit-path! block! paren! hash! string! file! url! tag! email! ref! integer! float! percent! point2D! point3D! money! char! pair! tuple! time! date! word! set-word! get-word! lit-word! refinement! issue! none! logic! datatype! typeset! handle! object! error! port! native! action! op! function! routine! map! bitset! unset!]
	]
	currencies: [
	    AED AFN ALL AMD ANG AOA ARS AUD AWG AZN BAM BBD BDT BTC BGN BHD BIF BMD BND BOB BRL BSD 
	    BTN BWP BYN BZD CAD CDF CHF CKD CLP CNY COP CRC CUC CUP CVE CZK DJF DKK DOP DZD EGP ERN 
	    ETB ETH EUR FJD FKP FOK GBP GEL GGP GHS GIP GMD GNF GTQ GYD HKD HNL HRK HTG HUF IDR ILS 
	    IMP INR IQD IRR ISK JEP JMD JOD JPY KES KGS KHR KID KMF KPW KRW KWD KYD KZT LAK LBP LKR 
	    LRD LSL LYD MAD MDL MGA MKD MMK MNT MOP MRU MUR MVR MWK MXN MYR MZN NAD NGN NIO NOK NPR 
	    NZD OMR PAB PEN PGK PHP PKR PLN PND PRB PYG QAR RED RON RSD RUB RWF SAR SBD SCR SDG SEK 
	    SGD SHP SLL SLS SOS SRD SSP STN SYP SZL THB TJS TMT TND TOP TRY TTD TVD TWD TZS UAH UGX 
	    USD UYU UZS VES VND VUV WST CFA XAF XCD XOF CFP XPF YER ZAR ZMW
	]
	extras: make block! 1

	data: none

	init: func [job [object!] /local src] [
		definitions: make map! definitions
		currencies: make hash! currencies
		clear extras
	]
]