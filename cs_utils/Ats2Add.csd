<CsoundSynthesizer>
<CsOptions>
-m128
--env:SADIR+=../res
--env:SSDIR+=../res
</CsOptions>
<CsInstruments>

sr = 44100
ksmps = 32
nchnls = 2
0dbfs = 1

/* joachim heintz
   ATS2ADD ANALYZER
   
   Analyzes the partials of a given sound at a certain position.
   Csound's ATSA utility must have been applied before (resulting in .ats file).
   
   For TIEMF workshop, feb/mar 2021
   
   NEEDED:
   1. .ats analysis file of any sound.
      This can be done with the ATSA utility (in command line or in CsoundQt's as:
      View -> Utilities > ATSA tab.
      Choose reasonable parameters for lowest (-l) and highest (-H) frequency.
      Choose "amp-freq" for file type (-F).
      NOTE: The adjustment of the (many) ATS parameters has a big impact on the result.
       So it may be worth to repeat the analysis several times until the best result is found.
   2. The sound file itself for comparison.
   
   USAGE:
   1. Insert below:
      a) gS_AtsFile: .ats file 
      b) gS_Sound: sound file (which was analyzed by ATSA)
      c) giPosition: position in sound file you want to analyze
      d) giNumPartials: number of partials you want to analyze
      e) giNormalize: 0 = keep the amplitudes as they are in the analysis
                      1 = normalize the amplitudes to sum up at 1
   2. Run the file. 
      A short part of the original sound is being played at the selected position.
      Then the result of the additive synthesis is played back with percussive envelope.
   3. Look at console output, to find the analysis results as printout, mainly
      - base frequency
      - proportions (ratios) of the partials
      - amplitudes (normalized or not) of the partials
*/


gS_AtsFile = "Santur.ats" ;ATSA -l 100 -H 10000
gS_Sound = "Santur.wav"
;gS_AtsFile = "glass.ats" ;ATSA -l 100 -H 10000
;gS_Sound = "glass.wav"
giPosition = 0.2 ;sec
giNumPartials = 7
giNormalize = 1 ;1 = scale amps to sum up to 1


opcode ArrSrt, k[], k[]jOOOP
 //see https://github.com/csudo/csudo/blob/master/arrays/ArrSrt.csd
 kArr[], iOutN, kOutType, kStart, kEnd, kHop xin
 ;calculate some common values 
 kLen lenarray kArr
 kEnd = kEnd > kLen || kEnd == 0 ? kLen : kEnd
 ;create the array for the result
 iOutN = (iOutN == -1) ? lenarray:i(kArr) : iOutN
 kRes[] init iOutN
 ;fill this array with the smallest number minus 1 of kArr
 kIndx = 0
 kMin minarray kArr
 while kIndx < iOutN do
  kRes[kIndx] = kMin-1
  kIndx += 1
 od
 ;if necessary, create index array
 if kOutType != 0 then
  kIndices[] init iOutN
 endif
 ;initialize pointer
 kArrPnt = kStart 
 ;loop over the elements of the array
 while kArrPnt < kEnd do
  ;loop over kRes
  kResPnt = 0
  while kResPnt < iOutN do
   ;if an el in kRes is smaller than the element we are comparing with
   if kRes[kResPnt] < kArr[kArrPnt] then
    ;shift the elements right to kResPnt one position to the right
    kShiftPnt = iOutN-1 
    while kShiftPnt > kResPnt do
     kRes[kShiftPnt] = kRes[kShiftPnt-1]
     kShiftPnt -= 1 
    od
    ;then put the element we are comparing with at this position
    kRes[kResPnt] = kArr[kArrPnt]
    ;if indices array 
    if kOutType != 0 then
     ;shift the elements in kIndices one position to the right
     kShiftPnt = iOutN-1 
     while kShiftPnt > kResPnt do
      kIndices[kShiftPnt] = kIndices[kShiftPnt-1]
      kShiftPnt -= 1
     od
     ;then put in the index
     kIndices[kResPnt] = kArrPnt
    endif
    ;and leave the loop
    kgoto Break 
   endif
   ;increase res pointer
   kResPnt += 1
  od  
  Break:
  ;increase array pointer
  kArrPnt += kHop
 od
 ;copy array to final result
 if kOutType == 0 then
 kOut[] = kRes
 else
 kOut[] = kIndices
 endif
 xout kOut
endop

instr Init
 giPartialsInATS ATSinfo gS_AtsFile, 3
 
 if giNumPartials > giPartialsInATS then
  prints "\nWARNING: Number of Partials requested exceeds the Number\
          of Partials in ATS file. Set to %d instead.\n", giPartialsInATS
  giNumPartials = giPartialsInATS
 else
  prints "\nNumber of Partials in ATS File: %d.\n", giPartialsInATS
  prints "Number of Partials requested: %d.\n", giNumPartials
 endif
 
 gkAmps[] init giPartialsInATS
 gkFreqs[] init giPartialsInATS
 indx = 0
 while indx < giPartialsInATS do
  schedule "WriteToArrays", 0, 1/kr, indx
  indx += 1
 od 
 schedule "Select", 2/kr, .1
endin

instr WriteToArrays
 iReadPosition = (giPosition < .02) ? .02 : giPosition
 kFreq, kAmp ATSread iReadPosition, gS_AtsFile, p4+1
 gkAmps[p4] = kAmp
 gkFreqs[p4] = kFreq
 turnoff
endin

instr Select
 gkAmpsSorted[] init giNumPartials
 gkFreqsSorted[] init giNumPartials
 kAmpsSort[] ArrSrt gkAmps, giNumPartials, 1
 kndx = 0
 while kndx < giNumPartials do
  kNextInRange = kAmpsSort[kndx]
  gkAmpsSorted[kndx] = gkAmps[kNextInRange]
  gkFreqsSorted[kndx] = gkFreqs[kNextInRange]
  kndx += 1
 od
 schedulek "PlayOrig", 0, .5
 schedulek "PlayPartials", 1, 3
 schedulek "Print", 0, 1
 turnoff
endin

instr Print
 kMinFreq minarray gkFreqsSorted
 printks "\nBase Frequency = %.3f\n", 0, kMinFreq
 kProps[] = gkFreqsSorted / kMinFreq
 kPropsSortIndx[] ArrSrt kProps, -1, 1 ;to be reversed
 kndx = giNumPartials-1
 printks "Proportions = ", 0
 while kndx >= 0 do
  kEl = kPropsSortIndx[kndx]
  printf "%f  ", kndx+1, kProps[kEl]
  kndx -= 1
 od
 kndx = giNumPartials-1
 printks "\nAmplitudes =  ", 0
 kAmpFac = (giNormalize==0) ? 1 : 1/sumarray(gkAmpsSorted)
 while kndx >= 0 do
  kEl = kPropsSortIndx[kndx]
  printf "%f  ", kndx+1, gkAmpsSorted[kEl]*kAmpFac
  kndx -= 1
 od
 printks "\n\n", 0
 turnoff
endin

instr PlayOrig
 aSnd[] diskin gS_Sound, 1, giPosition
 aOut linen aSnd[0], .003, p3, p3
 out aOut, aOut
endin

instr PlayPartials
 kndx = 0
 while kndx < giNumPartials do
  schedulek "Partial", 0, p3, gkAmpsSorted[kndx], gkFreqsSorted[kndx]
  kndx += 1
 od
 turnoff
endin

instr Partial
 iAmp = p4
 iFreq = p5
 aEnv transeg iAmp, p3, -3, 0
 aPartial poscil aEnv, iFreq
 out aPartial, aPartial
endin

</CsInstruments>
<CsScore>
i "Init" 0 3
</CsScore>
</CsoundSynthesizer>
