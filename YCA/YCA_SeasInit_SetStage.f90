!**********************************************************************************************************************
! This is the code from the section (DYNAMIC.EQ.RUNINIT) ! Initialization, lines 3109 - 3549 of the original CSCAS code.
! The names of the dummy arguments are the same as in the original CSCAS code and the call statement and are declared 
! here. The variables that are not arguments are declared in module YCA_First_Trans_m. Unless identified as by MF, all 
! comments are those of the original CSCAS.FOR code.
!
! Subroutine YCA_SeasInit_SetStage sets up the growth stages including branching, check coefficients, sets defaults and 
! calculates/sets initial states.
!**********************************************************************************************************************

    SUBROUTINE YCA_SeasInit_SetStage( &
        CN          , ISWNIT      , KCAN        , KEP         , RN          , RUN         , RUNI        , SLPF        , &
        TN           &
        )

        USE OSDefinitions
        USE YCA_First_Trans_m

        
        IMPLICIT NONE
        
        INTEGER CN          , RN          , RUN         , RUNI        , TN          
        INTEGER TVILENT                                                                       ! Integer function call.        
        
        REAL    KCAN        , KEP         , SLPF        
        
        CHARACTER(LEN=1) ISWNIT         
         
        !-----------------------------------------------------------------------
        !       Determine 'key' principal and secondary stages,and adjust names
        !-----------------------------------------------------------------------

        KEYPSNUM = 0
        PSNUM = 0
        !DO L = 1,PSX  !LPM 28MAR15 the first stage is 0 (before branching)
        DO L = 0,PSX-1
            IF (TVILENT(PSTYP(L)).GT.0) THEN                                            ! TVILENT is a function in CSUTS.FOR the same as the intrinsic function LEN_TRIM
                IF (PSTYP(L).EQ.'K'.OR.PSTYP(L).EQ.'k'.OR.PSTYP(L).EQ.'M')THEN          ! PSNO PSTYP PSABV PSNAME    (From .SPE file, S=Standard, K=Key)
                    KEYPSNUM = KEYPSNUM + 1                                             !    0     S GDAT  Germinate
                    KEYPS(KEYPSNUM) = L                                                 !    1     K B1DAT 1stBranch
                ENDIF                                                                   !    2     K B2DAT 2ndBranch
                IF (PSABV(L).EQ.'HDAT') HSTG = L                                        !    3     K B3DAT 3rdBranch
                !IF (PSABV(L).EQ.'MDAT') MSTG = L                                       !    4     K B4DAT 4thBranch !LPM 07MAR15 There is not a MSTG for cassava
                PSNUM = PSNUM + 1                                                       !    5     K B5DAT 5thBranch
            ENDIF                                                                       !    6     K B6DAT 6thBranch until branch level 10
        ENDDO                                                                           !   10     K B0DAT 10thBranch 
        ! IF MSTG not found, use maximum principal stage number                         
        !IF (MSTG.LE.0) THEN  !LPM 05JUN2015 MSTG is not used
        !    MSTG = KEYPSNUM
        !ENDIF
        ! IF HSTG not found, use maximum principal stage number + 1
        IF (HSTG.LE.0) THEN
            HSTG = PSX
            !HSTG = MSTG+1                  !LPM 07MAR15 MSTG to PSX
            !PSTART(HSTG) = 5000   ! Set to very long cycle !LPM 06MAR15 to avoid low values of PSTART with DEVU
        ENDIF
        ! Check and adjust stage abbreviations (DAT -> DAP)
        DO L = 1,PSNUM
            IF (TVILENT(PSABV(L)).GT.3) THEN
                IF (TVILENT(PSABV(L)).EQ.4) THEN
                    DO L1 = 5,1,-1
                        IF (L1.GT.1) THEN
                            PSABV(L)(L1:L1) = PSABV(L)(L1-1:L1-1)
                        ELSE
                            PSABV(L)(L1:L1) = ' '
                        ENDIF
                    ENDDO
                ENDIF
                PSABVO(L) = PSABV(L)
                ! DAS -> DAP for output
                PSABVO(L)(5:5) = 'P'
            ENDIF
        ENDDO
        
        !-----------------------------------------------------------------------
        !       Calculate/adjust branching tier durations and thresholds
        !-----------------------------------------------------------------------
        
        ! Find number of tiers
        !MSTG = 0 
        !IF (PDL(1).GT.0.0) THEN !LPM 04MAR15 remove to add IF (MEDEV.EQ.'LNUM')THEN
        DUTOMSTG = 0.0
        LNUMTOSTG = 0.0        
        !IF (MEDEV.EQ.'LNUM')THEN !LPM 04MAR15 MEDEV defines if branching durations input is as node unit (LNUM) !LPM 21MAY2015 this method is not used
        !    ! If tier durations input as node units,calculte DU for tiers
        !    DO L = 0,8 !LPM 07MAR15 here 8 is left (instead of PSX) to avoid problems with the estimation of DSTAGE
        !        IF (PDL(L).GT.0.0) THEN
        !            MSTG = L+1
        !            HSTG = MSTG+1  
        !        ENDIF 
        !    ENDDO
        !    ! Check for missing tier durations and if so use previous
        !    IF (MSTG.GT.2) THEN   !LPM 07MAR15 here MSTG is not changed to PSX to avoid problems with the estimation of DSTAGE
        !        DO L = 2,MSTG
        !            IF (PDL(L).LT.0.0) THEN
        !                PDL(L) = PDL(L-1)
        !            ENDIF
        !        ENDDO
        !    ENDIF  
        !    ! Calculate leaf # to MSTG
        !    TVR1 = 0.0
        !    DO L = 1,MSTG-1
        !        TVR1 = TVR1 + AMAX1(0.0,PDL(L))                                                                        !EQN 001
        !    ENDDO  
        !    ! Now calculate tier durations in Thermal Units
        !    TVR2 = 0.0
        !    LNUMTMP = 0.0
        !    DSTAGE = 0.0
        !    DO L = 1,1000
        !        TVR2 = TVR2 + STDAY
        !        TVR3 = 1.0/((1.0/PHINTS)*(1.0-AMIN1(.8,PHINTFAC*DSTAGE)))                                              !EQN 003
        !        ! TVR3 is a temporary name for PHINT within the loop 
        !        LNUMTMP = LNUMTMP + STDAY/TVR3
        !        DSTAGE = AMIN1(1.0,LNUM/TVR1)                                                                          !EQN 002
        !        IF(LNUMTMP.GE.PDL(1).AND.PSTART(2).LE.0.0) PSTART(2) = TVR2
        !        IF(LNUMTMP.GE.PDL(1)+PDL(2).AND.PSTART(3).LE.0.0) PSTART(3) = TVR2
        !        IF(LNUMTMP.GE.PDL(1)+PDL(2)+PDL(3).AND.PSTART(4).LE.0.0) PSTART(4) = TVR2
        !        IF(LNUMTMP.GE.PDL(1)+PDL(2)+PDL(3)+PDL(4).AND. PSTART(5).LE.0.0) PSTART(5) = TVR2
        !        IF(LNUMTMP.GE.PDL(1)+PDL(2)+PDL(3)+PDL(4)+PDL(5).AND.PSTART(6).LE.0.0) PSTART(6) = TVR2
        !        IF(LNUMTMP.GE.PDL(1)+PDL(2)+PDL(3)+PDL(4)+PDL(5)+PDL(6).AND.PSTART(7).LE.0.0) PSTART(7) = TVR2
        !        IF(LNUMTMP.GE.PDL(1)+PDL(2)+PDL(3)+PDL(4)+PDL(5)+PDL(6)+PDL(7).AND.PSTART(8).LE.0.0) PSTART(8) = TVR2
        !    ENDDO 
        !    DO L = 1,MSTG-1
        !        PD(L) = PSTART(L+1) - PSTART(L)
        !    ENDDO
        !    PDL(MSTG) = 200.0
        !    PD(MSTG) = PDL(MSTG)*PHINTS
        !    DSTAGE = 0.0
        !    
        !    DO L = 1, MSTG-1  !LPM 06MAR15 move because it should be part of the conditional 
        !    IF (PD(L).GT.0.0) THEN
        !        DUTOMSTG = DUTOMSTG + PD(L)
        !        LNUMTOSTG(L+1) = LNUMTOSTG(L) + PDL(L)                                                                 !EQN 006
        !    ENDIF  
        !    ENDDO
        !ELSE 
            ! If tier durations input as developmental units
            !DO L = 1,8  !LPM 06MAR15 to avoid a fix value of branch levelS (8)
        !DO L = 0,PSX    !LPM 05JUN2015 MSTG  is not used
        !    IF (PDL(L).GT.0.0) THEN
        !        MSTG = L+1
        !        HSTG = MSTG+1  
        !    ENDIF 
        !ENDDO
        ! Check for missing tier durations and if so use previous
            
        DO L = 0,PSX  !LPM 04MAR15 used to define PD as PDL (directly from the cultivar file as thermal time) 
            IF (L.LE.2)THEN
                PD(L) = PDL(L)
            ELSE
                PD(L) = PDL(2)
            ENDIF
        ENDDO
            
            !IF (MSTG.GT.2) THEN !LPM 07MAR15 MSTG to PSX
            IF (PSX.GT.2) THEN
                Ctrnumpd = 0
                !DO L = 2,MSTG-1  !LPM 04MAR15 It is not necessary the -1 because there is not a MSTG with a different value 
                DO L = 1,PSX
                    !IF (PD(L).LT.0.0) THEN !LPM 04MAR15 We use the same input data PDL instead of create a new coefficient (PD) 
                    IF (PDL(L).LT.0.0) THEN  
                        PDL(L) = PDL(L-1)
                        !PD(L) = PD(L-1) !LPM 04MAR15 We use the same input data PDL instead of create a new coefficient (PD)
                        PD(L) = PDL(L-1)
                        CTRNUMPD = CTRNUMPD + 1
                    ENDIF
                ENDDO
            ENDIF  
            !IF (CTRNUMPD.GT.0) THEN   !LPM 07mar15 It would not be necessary. B12ND would be used from the second branch     
            !    WRITE(MESSAGE(1),'(A11,I2,A24)') 'Duration of',CTRNUMPD,' branches less than zero. ' !LPM 04MAR15 tiers to branches
            !    MESSAGE(2)='Used value(s) for preceding branch. '
            !    CALL WARNING(2,'CSCAS',MESSAGE)
            !ENDIF
            !PDL(MSTG) = 200.0
            !PD(MSTG) = PDL(MSTG)  !LPM 04MAR15 PD as PDL (directly from the cultivar file as thermal time) 
        
            ! Calculate thresholds 
            !LPM 04MAR15 It should be part of the conditional (MEDEV== DEVU) to define the values of PSTART, 
            !if (MEDEV== LNUM) PSTART has been already defined (line 110-116)
            !DO L = 0,MSTG  !LPM 07MAR15 MSTG to PSX
            DO L = 0,PSX
                PSTART(L) = 0.0
            ENDDO
            !DO L = 0,MSTG  !LPM 07MAR15 MSTG to PSX
            DO L = 1,PSX
                PSTART(L) = PSTART(L-1) + AMAX1(0.0,PD(L))
            ENDDO
            
            !DO L = 1, MSTG-1  !LPM 07MAR15 MSTG to PSX
            DO L = 1, PSX-1
                IF (PD(L).GT.0.0) THEN
                    DUTOMSTG = DUTOMSTG + PD(L)
                    !LNUMTOSTG(L+1) = LNUMTOSTG(L) + PDL(L)  !LPM 04MAR15 it is estimated through the simulation                !EQN 006
                ENDIF  
            ENDDO
        !ENDIF  
        
        
      
        !IF (PHINTS.LE.0.0) THEN   !LPM 21MAY2015 this variable is not used
        !    OPEN (UNIT = FNUMERR,FILE = 'ERROR.OUT')
        !    WRITE(fnumerr,*) ' '
        !    WRITE(fnumerr,*) 'PHINT <= 0! Please correct genotype files.'
        !    WRITE(*,*) ' PHINT <= 0! Please correct genotype files.'
        !    WRITE(*,*) ' Program will have to stop'
        !    PAUSE
        !    CLOSE (fnumerr)
        !    STOP ' '
        !ENDIF
        
        ! Adjust germination duration for seed dormancy
        !LPM 21MAR
        !IF (PLMAGE.LT.0.0.AND.PLMAGE.GT.-90.0) THEN
        !    PEGD = PGERM - (PLMAGE*STDAY) ! Dormancy has negative age                                                  !EQN 045b
        !ELSE
        !    PEGD = PGERM
        !ENDIF
        
        !-----------------------------------------------------------------------
        !       Check and/or adjust coefficients and set defaults if not present
        !-----------------------------------------------------------------------
        
        DO L = 0,1
            LNCXS(L) = LNPCS(L)/100.0 
            SNCXS(L) = SNPCS(L)/100.0 
            RNCXS(L) = RNPCS(L)/100.0 
            LNCMN(L) = LNPCMN(L)/100.0
            SNCMN(L) = SNPCMN(L)/100.0
            RNCMN(L) = RNPCMN(L)/100.0
        ENDDO
        
        !IF (LA1S.LE.0.0) THEN                                                                  !DA 03OCT2016 Removing LA1S variable, use not significant for the model
        !    LA1S = 5.0
        !    WRITE(MESSAGE(1),'(A47)') 'Initial leaf size (LA1S) missing. Set to 5 cm2.'
        !    CALL WARNING(1,'CSCGR',MESSAGE)
        !ENDIF
        
        !IF (LAFND.GT.0.0.AND.LAFND.LE.LAXNO.OR.LAFND.LT.0) THEN
        !    LAFND = LAXNO + 10
        !    WRITE(MESSAGE(1),'(A59)') 'Leaf # for final size missing or < maximum! Set to max+10.'
        !    CALL WARNING(1,'CSCGR',MESSAGE)
        !ENDIF
        IF (DFPE.LT.0.0) THEN  
            DFPE = 1.0
            WRITE(MESSAGE(1),'(A51)') 'Pre-emergence development factor missing. Set to 1.'
            CALL WARNING(1,'CSYCA',MESSAGE)
        ENDIF
        
        ! Stem fraction constant throughout lifecycle
        !IF (SWFRS.GT.0.0) THEN  !LPM 05JUN2015 SWFRS is not used
        !    SWFRX = SWFRS
        !    SWFRXL = 9999
        !    SWFRN = SWFRS
        !    SWFRNL = 0
        !ENDIF 
        
        ! Storage root 
        !IF (SRFR.LT.0.0) SRFR = 0.0 !LPM 08 JUN2015 SRFR is not used   
        ! IF (HMPC.LE.0.0) HMPC = 50.0 !issue 49 20JUN2015 Hmpc is not used
        
        ! Nitrogen uptake                  
        IF (rtno3.le.0.0) RTNO3 = 0.006  ! NO3 uptake/root lgth (mgN/cm)
        IF (rtnh4.le.0.0) RTNH4 = RTNO3  ! NH4 uptake/root lgth (mgN/cm)
        IF (h2ocf.lt.0.0) H2OCF = 1.0    ! H2O conc factor for N uptake 
        IF (no3cf.lt.0.0) NO3CF = 1.0    ! NO3 uptake conc factor (exp)
        IF (nh4cf.lt.0.0) NH4CF = NO3CF  ! NH4 uptake factor (exponent) 
        
        ! Radiation use efficiency
        IF (PARUE.LE.0.0) PARUE = 2.3
        
        ! Leaves
        IF (PHINTFAC.LE.0.0) PHINTFAC = 0.8
        !IF (LA1S.LT.0.0) LA1S = 5.0                             !DA 03OCT2016 Removing LA1S variable, is not used according to LPM 07MAR15     
        IF (LAXS.LT.0.0) LAXS = 200.0
        IF (LWLOS.LT.0.0) LWLOS = 0.3
        IF (LPEFR.LT.0.0) LPEFR = 0.33
        
        ! Roots
        IF (RDGS.LT.0.0) RDGS = 3.0
        IF (RSEN.LT.0.0) RSEN = 5.0
        
        ! Reduction factor limits
        IF (WFPL.LT.0.0) WFPL = 0.0
        IF (WFPU.LT.0.0) WFPU = 1.0
        IF (WFGL.LT.0.0) WFGL = 0.0
        IF (WFGU.LT.0.0) WFGU = 1.0
        IF (NFPL.LT.0.0) NFPL = 0.0
        IF (NFPU.LT.0.0) NFPU = 1.0
        IF (NFGL.LT.0.0) NFGL = 0.0
        IF (NFGU.LT.0.0) NFGU = 1.0
        IF (NLLG.LE.0.0) NLLG = 0.95
        IF (NFSU.LT.0.0) NFSU = 0.2
        
        ! Various
        IF (RSFRS.LT.0.0) RSFRS = 0.05
        IF (LSENI.LT.0.0) LSENI = 0.0
        IF (PARIX.LE.0.0) PARIX = 0.995
        IF (NTUPF.LT.0.0) NTUPF = 0.2
        IF (PPEXP.LT.0.0) PPEXP = 2.0
        IF (RLFWU.LT.0.0) RLFWU = 0.5  
        IF (RTUFR.LT.0.0) RTUFR = 0.05
        IF (BRFX(1).LE.0.0) BRFX(1) = 3.0
        IF (BRFX(2).LE.0.0) BRFX(2) = 3.0
        IF (BRFX(3).LE.0.0) BRFX(3) = 3.0
        IF (BRFX(4).LE.0.0) BRFX(4) = 3.0
        IF (BRFX(5).LE.0.0) BRFX(5) = BRFX(4) !LPM 06JUL2017 Use BRFX(4) for branch level higher than 4
        IF (BRFX(6).LE.0.0) BRFX(6) = BRFX(4)
        IF (SHGR(20).LT.0.0) THEN 
            DO L = 3,22
                SHGR(L) = 1.0 !  Shoot sizes relative to main shoot
            ENDDO
        ENDIF
        
        IF (SLPF.LE.0.0 .OR. SLPF.GT.1.0) SLPF = 1.0
        IF (SLPF.LT.1.0) THEN
            WRITE (fnumwrk,*) ' '
            WRITE (fnumwrk,'(A42,F5.1)') ' Soil fertility factor was less than 1.0: ',slpf
        ENDIF  
        
        IF (PLPH.LE.0.0) THEN
            WRITE (fnumwrk,*) ' '
            WRITE (fnumwrk,'(A27,F6.1,A14)') ' Plants per hill <= 0.0 at ',PLPH,'  Reset to 1.0'
            PLPH = 1.0
        ENDIF  
        
        ! Soil inorganic N uptake aspects
        IF (NO3MN.LT.0.0) NO3MN = 0.5
        IF (NH4MN.LT.0.0) NH4MN = 0.5
        
        
        !-----------------------------------------------------------------------
        !       Calculate derived coefficients and set equivalences
        !-----------------------------------------------------------------------
        
        ! Initial leaf growth aspects
        !LAPOTX(1) = LA1S !LPM 07MAR15 LA1S will not be used and it is assumed as 0.1*LAXS
        !plant(0,1)%LAPOTX = LAXS*0.1
        
        ! If max LAI not read-in,calculate from max interception
        IF (LAIXX.LE.0.0) LAIXX = LOG(1.0-PARIX)/(-KCAN)                                                               ! EQN 008
        
        !PHINT = PHINTS  !LPM 21MAY2015 this variable is not used
        
        ! Leaf life
        !IF (CFLLFLIFE.EQ.'P')THEN   !LPM 21MAY2015 this variable (PHINT) is not used
        !    ! Read-in as phyllochrons 
        !    LLIFGTT = LLIFG * PHINT                                                                                    !EQN 349
        !    LLIFATT = LLIFA * PHINT                                                                                    !EQN 350 
        !    LLIFSTT = LLIFS * PHINT                                                                                    !EQN 351 
        !ELSEIF (CFLLFLIFE.EQ.'T')THEN
        IF (CFLLFLIFE.EQ.'T')THEN
            ! Read-in as thermal time 
            LLIFGTT = LLIFG                                                                                            !EQN 352
            LLIFATT = LLIFA                                                                                            !EQN 353 
            LLIFSTT = LLIFS                                                                                            !EQN 354
        !ELSEIF (CFLLFLIFE.EQ.'D')THEN
        !    ! Read-in as days. Thermal time for each day set to PHINT
        !    LLIFGTT = LLIFG * PHINT                                                                                    !EQN 355 
        !    LLIFATT = LLIFA * PHINT                                                                                    !EQN 356 
        !    LLIFSTT = LLIFS * PHINT                                                                                    !EQN 357 
        ENDIF  
        
        ! Extinction coeff for SRAD
        KEP = (KCAN/(1.0-TPAR)) * (1.0-TSRAD)                                                                          ! EQN 009
        
        ! Photoperiod sensitivities
        DO L = 0,10
            IF (DAYLS(L).LT.0.0) DAYLS(L) = 0.0
        ENDDO
        IF (Dayls(1).EQ.0.0.AND.dfpe.LT.1.0) THEN
            WRITE(MESSAGE(1),'(A36,A41)') 'Cultivar insensitive to photoperiod ', 'but pre-emergence photoperiod factor < 1.' 
            WRITE(MESSAGE(2),'(A40)') 'May be worthwhile to change PPFPE to 1.0'
            CALL WARNING(2,'CSYCA',MESSAGE)
        ENDIF
        
        ! Shoot growth rates relative to main shoot
        IF (SHGR(20).GE.0.0) THEN
            DO L = 3,22
                IF (L.LT.20) THEN
                    SHGR(L) = SHGR(2)-((SHGR(2)-SHGR(20))/18)*(L-2)                                                    !EQN 010
                ELSEIF (L.GT.20) THEN
                    SHGR(L) = SHGR(20)
                ENDIF  
            ENDDO
        ENDIF
        
        ! Critical and starting N concentrations
        LNCX = LNCXS(0)
        plant%SNCX = SNCXS(0)
        RNCX = RNCXS(0)
        LNCM = LNCMN(0)
        plant%SNCM = SNCMN(0)
        RNCM = RNCMN(0)
        
        ! Storage root N  NB.Conversion protein->N factor = 6.25
        IF (SRNPCS.LE.0.0) THEN
            IF(SRPRS.GT.0.0) THEN
                SRNPCS = SRPRS / 6.25                                                                                  !EQN 023
            ELSE
                SRNPCS = 0.65
            ENDIF
        ENDIF       
        
        ! Height growth
        !SERX = CANHTS/PSTART(MSTG) change to br. level 6 to avoid that it takes long time to increase CANHT            !EQN 315
        !SERX = CANHTS/PSTART(6) LPM 06JUL2017 SERX will not be used
        
        !-----------------------------------------------------------------------
        !       Set coefficients that dependent on input switch
        !-----------------------------------------------------------------------
        
        IF (ISWWATCROP.EQ.'N') THEN
            ! Plant water status effects on growth turned off
            WFGU = 0.0
            WFPU = 0.0
            WFSU = 0.0
            WFRTG = 0.0
        ENDIF
        
        !-----------------------------------------------------------------------
        !       Calculate/set initial states
        !-----------------------------------------------------------------------
        
        !LPM 22MAR2016 To use SEEDRS from emergence 
        !IF (SDRATE.LE.0.0) SDRATE = SDSZ*PPOP*10.0                                                                  !EQN 024 !LPM 06MAR2016 To have just one name for PPOP
        IF (SDRATE.LE.0.0) SDRATE = SDSZ*SPRL*PPOP*10.0   
        ! Reserves = SDRS% of seed                                                                                  !LPM 22MAR2016 Keep value SDRS  
        SEEDRSI = (SDRATE/(PPOP*10.0))*SDRS/100.0                                                                  !EQN 284 !LPM 06MAR2016 To have just one name for PPOP
        SEEDRS = SEEDRSI
        SEEDRSAV = SEEDRS
        SDCOAT = (SDRATE/(PPOP*10.0))*(1.0-SDRS/100.0)                                                             !EQN 025 !LPM 06MAR2016 To have just one name for PPOP
        ! Seed N calculated from total seed
        SDNAP = (SDNPCI/100.0)*SDRATE                                                                                  !EQN 026
        SEEDNI = (SDNPCI/100.0)*(SDRATE/(PPOP*10.0))                                                                !EQN 027
        IF (ISWNIT /= 'N') THEN
            SEEDN = SEEDNI
            WRITE(MESSAGE(1),'(A39)') 'Simulations with N are under evaluation'
            WRITE(MESSAGE(2),'(A68)') 'it could affect your results, consider to turn off N for simulations'
            CALL WARNING(2,'CSYCA',MESSAGE)
        ELSE
            SEEDN = 0.0
            SDNAP = 0.0
            SEEDNI = 0.0
        ENDIF
        
        ! Water table depth
        WTDEP = ICWD
        
        ! Initial shoot and root placement
        IF (PLME.NE.'I') THEN
            IF (PLME.NE.'H') THEN
                IF (PLME.NE.'V') THEN
                    WRITE(MESSAGE(1),'(A16,A1,A15,A24)') 'PLANTING method ',PLME,' not an option ', ' Changed to V (Vertical)'
                    CALL WARNING(1,'CSYCA',MESSAGE)
                    WRITE(FNUMWRK,*)' '
                    WRITE(FNUMWRK,'(A17,A1,A15,A24)') ' Planting method ',PLME,' not an option ', ' Changed to V (Vertical)'
                    PLME = 'V'
                ENDIF
            ENDIF
        ENDIF
        IF (SPRL.LE.0.0) THEN
            WRITE(MESSAGE(1),'(A30,A20)') 'Planting stick length <= 00  ', ' Changed to 25.0 cm '
            CALL WARNING(1,'CSYCA',MESSAGE)
            WRITE(FNUMWRK,*)' '
            WRITE(FNUMWRK,'(A31,A20)') ' Planting stick length <= 0.0  ', ' Changed to 25.0 cm '
            SPRL = 25.0
        ENDIF
        sdepthu = -99.0
        IF (PLME.EQ.'H') THEN
            sdepthu = sdepth
        ELSEIF (PLME.EQ.'I') THEN
            ! Assumes that inclined at 45o
            !sdepthu = AMAX1(0.0,sdepth - 0.707*sprl)                                                                   !EQN 028 !LPM 22MAR2016 Modified to consider buds at 2.5 cm from the top end of the stake
            sdepthu = sdepth - 0.707*(sprl-2.5)                                                                  !EQN 028
        ELSEIF (PLME.EQ.'V') THEN
            !sdepthu = AMAX1(0.0,sdepth - sprl)                                                                         !EQN 029 !LPM 22MAR2016 Modified to consider buds at 2.5 cm from the top end of the stake
            sdepthu = sdepth - (sprl-2.5)                                                                        !EQN 029
        ENDIF
        !IF (sdepthu.LT.0.0) sdepthu = sdepth                                                                    !LPM 22MAR2016 Modified to assume that top of stake is in the soil surface (when it is above)
        IF (sdepthu.LT.0.0) sdepthu = 0.0 
        
    END SUBROUTINE YCA_SeasInit_SetStage