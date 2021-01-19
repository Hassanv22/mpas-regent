import "regent"
require "data_structures"

local constants = require("constants")
local c = regentlib.c

fabs = regentlib.fabs(double)
floor = regentlib.floor(double)
fmod = regentlib.fmod(double, double)
float = regentlib.float(int)
int = regentlib.int(double)

-- Struct of two factors
struct two_factors {
  fact1 : double,
  fact2 : double,
}

-- check sanity of time interpolation factors to within 32-bit roundoff
task validfactors(fact1 : double,
                  fact2 : double)
  var delta : double = 1.e-6
  if (fabs(fact1 + fact2 - 1.0) > delta or
      fact1 > 1.0 + delta or fact1 < -1 * delta or
      fact2 > 1.0 + delta or fact2 < -1 * delta) then
    return false
  end
  return true
end

-- Purpose: Determine time interpolation factors (normally for a boundary dataset)
--          for linear interpolation.
--
-- Method:  Assume 365 days per year.  Output variable fact1 will be the weight to
--          apply to data at calendar time "cdayminus", and fact2 the weight to apply
--          to data at time "cdayplus".  Combining these values will produce a result
--          valid at time "cday".  Output arguments fact1 and fact2 will be between
--          0 and 1, and fact1 + fact2 = 1 to roundoff.
task getfactors(cycflag : bool,
                np1 : int,
                cdayminus : double,
                cdayplus : double,
                cday : double)
  
  var tf : two_factors

  -- Determine time interpolation factors.  Account for December-January
  -- interpolation if dataset is being cycled yearly.
  if cycflag and np1 == 1 then
    var deltat : double = cdayplus + constants.daysperyear - cdayminus
    if cday > cdayplus then
      tf.fact1 = (cdayplus + constants.daysperyear - cday) / deltat
      tf.fact2 = (cday - cdayminus) / deltat
    else
      tf.fact1 = (cdayplus - cday) / deltat
      tf.fact2 = (cday + constants.daysperyear - cdayminus) / deltat
    end
  else
    var deltat : double = cdayplus - cdayminus
    tf.fact1 = (cdayplus - cday) / deltat
    tf.fact2 = (cday - cdayminus) / deltat
  end

  if validfactors(tf.fact1, tf.fact2) ~= true then
    c.printf("Bad fact1 and/or fact2=%.3f,%.3f\n", tf.fact1, tf.fact2)
  end

  return tf
end

task oznint(julian : double,
            ozmixmj : region(ispace(int3d), double),
            ozmix : region(ispace(int2d), double),
            levsiz : int,
            pcols : int,
            ozncyc : bool)
where
  reads (ozmixmj),
  writes (ozmix)
do

  -- julian starts from 0.0 at 0Z on 1 Jan.
  var intjulian : double = julian + 1.0    -- offset by one day
  -- jan 1st 00z is julian = 1.0 here
  var ijul : int = floor(intjulian)
  -- Note that following will drift. 
  -- Need to use actual month/day info to compute julian.
  intjulian = intjulian - ijul
  ijul = fmod(ijul, constants.daysperyear)
  if (ijul == 0) then 
    ijul = constants.daysperyear 
  end
  intjulian = intjulian + ijul

  var date_oz = array(16, 45, 75, 105, 136, 166, 197, 228, 258, 289, 319, 350)
  var np1 : int = 0
  var finddate : bool = false
  -- do m = 1, constants.nMonths
  for m = 0, constants.nMonths do
    if(date_oz[m] > intjulian and finddate == false) then
      np1 = m
      finddate = true
    end
  end

  var cdayozp : double = date_oz[np1]
  var cdayozm : double
  var np : int
  var nm : int
  if np1 > 0 then
    cdayozm = date_oz[np1 - 1]
    np = np1
    nm = np-1
  else
    cdayozm = date_oz[11]
    np = np1
    nm = 11
  end

  var tf : two_factors = getfactors(ozncyc, np1, cdayozm, cdayozp, intjulian)
  var fact1 : double = tf.fact1
  var fact2 : double = tf.fact2

  -- Time interpolation
  for k = 0, levsiz do 
    for i = 0, pcols do
      ozmix[{i, k}] = ozmixmj[{i, k, nm}] * fact1 + ozmixmj[{i, k, np}] * fact2
    end
  end

end

-- Purpose: Interpolate ozone from current time-interpolated values to model levels
--
-- Method: Use pressure values to determine interpolation levels
task radozn(cr : region(ispace(int2d), cell_fs),
            radctl_2d_pverr_r : region(ispace(int2d), radctl_2d_pverr_fs),
            ncol : int,     -- number of atmospheric columns
            pcols : int,
            pver : int,
            pin : region(ispace(int1d), double),     -- ozone data level pressures (mks)
            levsiz : int,                            -- number of ozone layers
            ozmix : region(ispace(int2d), double))   -- ozone mixing ratio
where
  reads (cr.pmid, pin, ozmix),
  writes (radctl_2d_pverr_r.o3vmr)
do
  --
  -- Initialize index array
  --
  var kupper = region(ispace(int1d, pcols), int)     -- Level indices for interpolation
  for i=0, ncol do
    kupper[i] = 1
  end

  for k=0, pver do
    --
    -- Top level we need to start looking is the top level for the previous k
    -- for all longitude points
    --
    var kkstart : int = levsiz
    for i=0, ncol do
      kkstart = min(kkstart, kupper[i])
    end

    --
    -- Store level indices for interpolation
    --
    var kount : int = 0
    var iter_done : bool = false
    for kk=kkstart, levsiz - 1 do
      for i=0, ncol do
        if ((pin[kk] < cr[{i, k}].pmid) and (cr[{i, k}].pmid < pin[kk + 1])) then
          kupper[i] = kk
          kount = kount + 1
        end
      end

      --
      -- If all indices for this level have been found, do the interpolation and
      -- go to the next level
      --
      if (kount == ncol) then
        iter_done = true
        for i=0, ncol do
          var dpu : double = cr[{i, k}].pmid - pin[kupper[i]]
          var dpl : double = pin[kupper[i] + 1] - cr[{i, k}].pmid
          radctl_2d_pverr_r[{i, k}].o3vmr = (ozmix[{i, kupper[i]}] * dpl + ozmix[{i, kupper[i] + 1}] * dpu) / (dpl + dpu)
        end
        break
      end
    end

    if not iter_done then
      --
      -- If we've fallen through the kk=1,levsiz-1 loop, we cannot interpolate and
      -- must extrapolate from the bottom or top ozone data level for at least some
      -- of the longitude points.
      --
      for i=0, ncol do
        if (cr[{i, k}].pmid < pin[0]) then
          radctl_2d_pverr_r[{i, k}].o3vmr = ozmix[{i, 0}] * cr[{i, k}].pmid / pin[0]
        elseif (cr[{i, k}].pmid > pin[levsiz]) then
          radctl_2d_pverr_r[{i, k}].o3vmr = ozmix[{i, levsiz}]
        else
          var dpu : double = cr[{i, k}].pmid - pin[kupper[i]]
          var dpl : double = pin[kupper[i] + 1] - cr[{i, k}].pmid
          radctl_2d_pverr_r[{i, k}].o3vmr = (ozmix[{i, kupper[i]}] * dpl + ozmix[{i, kupper[i] + 1}] * dpu) / (dpl + dpu)
        end
      end
    end

  end
end


-- From MPAS-Model/src/core_atmosphere/physics/physics_wrf/module_ra_cam.F
--
-- Purpose: 
-- Set latitude and time dependent arrays for input to solar
-- and longwave radiation.
-- Convert model pressures to cgs, and compute ozone mixing ratio, needed for
-- the solar radiation.
--
-- NOTE: variable eccf is unused everywhere, so not included in regent version
task radinp(cr : region(ispace(int2d), cell_fs),
            radctl_2d_pverr_r : region(ispace(int2d), radctl_2d_pverr_fs),
            radctl_2d_pverrp_r : region(ispace(int2d), radctl_2d_pverrp_fs),
            ncol : int,         -- number of atmospheric columns
            pver : int,
            pverp : int)
where
  reads (
    cr.{pmid, pint}, 
    radctl_2d_pverr_r.o3vmr
  ),
  writes (
    cr.pmid,
    radctl_2d_pverr_r.{pbr, o3mmr}, 
    radctl_2d_pverrp_r.pnm
  )
do
  ---------------------------Local variables-----------------------------
  var i : int           -- Longitude loop index
  var k : int           -- Vertical loop index

  var calday : double   -- current calendar day
  var vmmr : double     -- Ozone volume mixing ratio
  var delta : double    -- Solar declination angle
  -----------------------------------------------------------------------

  -- Convert pressure from pascals to dynes/cm2
  for k=0, pver do
    for i=0, ncol do
        radctl_2d_pverr_r[{i, k}].pbr = cr[{i, k}].pmid * 10.0
        radctl_2d_pverrp_r[{i, k}].pnm = cr[{i, k}].pint * 10.0
      end
  end
  for i=0, ncol do
    radctl_2d_pverrp_r[{i, pverp}].pnm = cr[{i, pverp}].pint * 10.0
  end

  -- Convert ozone volume mixing ratio to mass mixing ratio:
  vmmr = constants.amo / constants.amd
  for cell in radctl_2d_pverr_r do
    radctl_2d_pverr_r[cell].o3mmr = vmmr * radctl_2d_pverr_r[cell].o3vmr
  end

  return
end

--
-- Saturation vapor pressure table lookup
--
task estblf(td : double,            -- Temperature for saturation lookup  
            phys_tbls : region(ispace(int1d), phys_tbls_fs))
where
  reads (phys_tbls.{tmin, tmax, estbl})
do
  var e : double = max(min(td, phys_tbls[0].tmax), phys_tbls[0].tmin)   -- partial pressure
  var i : int = int(e - phys_tbls[0].tmin) + 1
  var ai : double = int(e - phys_tbls[0].tmin)

  return (phys_tbls[0].tmin + ai - e + 1.0) * 
         phys_tbls[0].estbl[i] - (phys_tbls[0].tmin + ai - e) * 
         phys_tbls[0].estbl[i + 1]
end

-- From MPAS-Model/src/core_atmosphere/physics/physics_wrf/module_ra_cam_support.F
--
-- Purpose: 
-- Utility procedure to look up and return saturation vapor pressure from
-- precomputed table, calculate and return saturation specific humidity
-- (g/g),for input arrays of temperature and pressure (dimensioned ii,kk)
-- This routine is useful for evaluating only a selected region in the
-- vertical.
task aqsat(cr : region(ispace(int2d), cell_fs),
           phys_tbls : region(ispace(int1d), phys_tbls_fs),
           radctl_2d_pverr_r : region(ispace(int2d), radctl_2d_pverr_fs),
           ilen : int,           -- Length of vectors in I direction which
           klen : int)          -- Length of K direction
where
  reads (cr.t, phys_tbls),
  reads writes (
    cr.pmid,
    radctl_2d_pverr_r.{esat, qsat}
  )
do
  var omeps = 1.0 - constants.ep_2
  var k : int
  var i : int
  for k = 0, klen do
    for i = 0, ilen do
      radctl_2d_pverr_r[{i, k}].esat = estblf(cr[{i, k}].t, phys_tbls)

      --
      -- Saturation specific humidity
      --
      radctl_2d_pverr_r[{i, k}].qsat = 
        constants.ep_2 * radctl_2d_pverr_r[{i, k}].esat 
        / (cr[{i, k}].pmid - omeps * radctl_2d_pverr_r[{i, k}].esat)

      --
      -- The following check is to avoid the generation of negative values
      -- that can occur in the upper stratosphere and mesosphere
      --
      radctl_2d_pverr_r[{i, k}].qsat = min(1.0, radctl_2d_pverr_r[{i, k}].qsat)

      if (radctl_2d_pverr_r[{i, k}].qsat < 0.0) then
        radctl_2d_pverr_r[{i, k}].qsat = 1.0
        radctl_2d_pverr_r[{i, k}].esat = cr[{i, k}].pmid
      end
    end
  end
end

-- From MPAS-Model/src/core_atmosphere/physics/physics_wrf/module_ra_cam_support.F
--
task get_rf_scales(scales : region(ispace(int1d), double)) -- scaling factors for aerosols
  scales(idxBG) = bgscl_rf
  scales(idxSUL) = sulscl_rf
  scales(idxSSLT) = ssltscl_rf

  var i : int
  do i = idxCARBONfirst, idxCARBONfirst + numCARBON-1
    scales(i) = carscl_rf
  end

  do i = idxDUSTfirst, idxDUSTfirst + numDUST-1
    scales(i) = dustscl_rf
  end

  scales(idxVOLC) = volcscl_rf
end

task vert_interpolate()
end

task background()
end

task scale_aerosols()
end

-- From MPAS-Model/src/core_atmosphere/physics/physics_wrf/module_ra_cam.F
--
-- Input:
--    time at which aerosol mmrs are needed (get_curr_calday())
--    chunk index
--    CAM's vertical grid (pint)
--
-- Output:
--    values for Aerosol Mass Mixing Ratios at specified time
--    on vertical grid specified by CAM (AEROSOLt)
--
-- Method:
--    first determine which indexs of aerosols are the bounding data sets
--    interpolate both onto vertical grid aerm(),aerp().
--    from those two, interpolate in time.
--
-- use volcanicmass, only: get_volcanic_mass
-- use timeinterp, only: getfactors
--
-- aerosol fields interpolated to current time step
--   on pressure levels of this time step.
-- these should be made read-only for other modules
-- Is allocation done correctly here?
--
task get_aerosol(cr : region(ispace(int2d), cell_fs),
                 c : int,                 -- Chunk Id
                 julian : double,
                 aerosoljp : region(ispace(int3d), double),
                 aerosoljn : region(ispace(int3d), double),
                 m_hybi : double[paerlev],
                 paerlev : int,
                 naer_c : int,
                 pint : double[pcols, pverp],       -- midpoint pres
                 pcols : int, 
                 pver : int,
                 pverp : int,
                 pverr : int,
                 pverrp : int,
                 AEROSOLt : double[pcols, pver, naer_all],          -- aerosols
                 scale : double[naer_all])          -- scale each aerosol by this amount
where
  reads (cr.{m_psp, m_psn}),
  writes ()
do
  --
  -- Local workspace
  --
  var caldayloc : double            -- calendar day of current timestep
  var fact1 : double                -- time interpolation factors
  var fact2 : double                  

  var nm : int = 1                  -- index to prv month in array. init to 1 and toggle between 1 and 2
  var np : int = 2                  -- index to nxt month in array. init to 2 and toggle between 1 and 2
  var mo_nxt : int = bigint         -- index to nxt month in file
  var mo_prv : int                  -- index to previous month

  var cdaym : double = inf          -- calendar day of prv month
  var cdayp : double = inf          -- calendar day of next month
  var Mid : double[12] = [16.5, 46.0, 75.5, 106.0, 136.5, 167.0, 197.5, 228.5, 259.0, 289.5, 320.0, 350.5]              
                                    -- Days into year for mid month date

  var i : int                       -- spatial indices
  var k : int
  var j : int
  var m : int                       -- constituent index
  var lats : int[pcols]             -- latitude and longitudes of column
  var lons : int[pcols]
  var ncol : int                    -- number of columns
  var IJUL : int
  var intJULIAN : double

  var speciesmin : double[naer]     -- minimal value for each species
  
  -- values before current time step "the minus month"
  -- aerosolm(pcols,pver) is value of preceeding month's aerosol mmr
  -- aerosolp(pcols,pver) is value of next month's aerosol mmr
  --  (think minus and plus or values to left and right of point to be interpolated)
  var AEROSOLm : double[pcols,pver,naer]      -- aerosol mmr from MATCH in column at previous (minus) month

  -- values beyond (or at) current time step "the plus month"
  var AEROSOLp : double[pcols,pver,naer]          -- aerosol mmr from MATCH in column at next (plus) month

  -- JULIAN starts from 0.0 at 0Z on 1 Jan.
  intJULIAN = JULIAN + 1.0_r8    -- offset by one day
  -- jan 1st 00z is julian=1.0 here
  IJUL = int(intJULIAN)
  -- Note that following will drift. 
  -- Need to use actual month/day info to compute julian.
  intJULIAN = intJULIAN - float(IJUL)
  IJUL = fmod(IJUL, 365)
  if (IJUL == 0) then
    IJUL = 365
  end
  caldayloc = intJULIAN + IJUL

  if (caldayloc < Mid(1)) then
    mo_prv = 12
    mo_nxt =  1
  else if (caldayloc >= Mid(12)) then
    mo_prv = 12
    mo_nxt =  1
  else
    do i = 2 , 12
      if (caldayloc < Mid(i)) then
        mo_prv = i-1
        mo_nxt = i
        exit
      end
    end
  end

  -- Set initial calendar day values
  cdaym = Mid[mo_prv]
  cdayp = Mid[mo_nxt]

  -- Determine time interpolation factors.  1st arg says we are cycling 1 year of data
  getfactors(true, mo_nxt, cdaym, cdayp, caldayloc, fact1, fact2)

  -- interpolate (prv and nxt month) bounding datasets onto cam vertical grid.
  -- compute mass mixing ratios on CAMS's pressure coordinate
  --  for both the "minus" and "plus" months
  ncol = pcols

  call vert_interpolate(m_psp, aerosoljp, m_hybi, paerlev, naer_c, pint, nm, AEROSOLm, pcols, pver, pverp, ncol, c)
  call vert_interpolate(m_psn, aerosoljn, m_hybi, paerlev, naer_c, pint, np, AEROSOLp, pcols, pver, pverp, ncol, c)

  -- Time interpolate.
  for m = 0, naer
    for k = 0, pver
      for i = 0, ncol
        AEROSOLt[i,k,m] = AEROSOLm[i,k,m] * fact1 + AEROSOLp[i,k,m] * fact2
      end
    end
  end

  -- get background aerosol (tuning) field
  background(c, ncol, pint, pcols, pverr, pverrp, AEROSOLt[:, :, idxBG])

  -- find volcanic aerosol masses
  AEROSOLt[:,:,idxVOLC] = 0._r8

  -- exit if mmr is negative (we have previously set
  --  cumulative mass to be a decreasing function.)
  speciesmin[:] = 0.        -- speciesmin(m) = 0 is minimum mmr for each species

  -- scale any AEROSOLS as required
  scale_aerosols(AEROSOLt, pcols, pver, ncol, c, scale)

end

task aerosol_indirect()
end

task radcswmx()
end

task get_int_scales()
end

task radclwmx()
end

task trcmix()
end