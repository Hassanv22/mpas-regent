import "regent"

local cio = terralib.includec("stdio.h")
local clib = terralib.includec("stdlib.h")

terralib.linklibrary("/share/software/user/open/netcdf/4.4.1.1/lib/libnetcdf.so")
local netcdf = terralib.includec("/share/software/user/open/netcdf/4.4.1.1/include/netcdf.h")

local nCells = 2562
local nEdges = 7680
local nVertices = 5120
local maxEdges = 10
local maxEdges2 = 20
local TWO = 2
local vertexDegree = 3
local nVertLevels = 1

local FILE_NAME = "x1.2562.grid.nc"

--Field space with location of center of primal-mesh cells
fspace x_i {
  {lat, lon} : double
}

--Task to create region
task create_element_regions()
    var x_i_region = region(ispace(ptr, nCells), x_i)
end

--Terra function to open the netcdf file and store NCID in the variable passed in.
terra open_file(ncid: &int, file_name: &int8)
	var retval = netcdf.nc_open(file_name, netcdf.NC_NOWRITE, ncid)
    if retval == 1 then 
        cio.printf("Error opening file %s \n", file_name)
    end
end

--Terra function to extract file information (no. of dims, etc).
terra file_inquiry(ncid: int, ndims_in: &int , nvars_in: &int, ngatts_in: &int, unlimdimid_in: &int)
	var retval = netcdf.nc_inq(ncid, ndims_in, nvars_in, ngatts_in, unlimdimid_in)
    if retval == 1 then 
        cio.printf("Error extracting file information of NCID %d \n", ncid)
    end
end

--Terra function to get the variable ID, given the variable name.
terra get_varid(ncid: int, name: &int8,  varid: &int)
	var retval = netcdf.nc_inq_varid(ncid, name, varid)
    if retval == 1 then 
        cio.printf("Error extracting variable ID of %s\n", name)
    end
	return varid
end

--Terra function to get the variable values, given the variable ID: For variables with type double.
terra get_var_double(ncid: int, varid: int,  var_array_ptr: &double)
	var retval = netcdf.nc_get_var_double(ncid, varid, var_array_ptr)
    if retval == 1 then 
        cio.printf("Error extracting variable values of variable ID %d\n", varid)
    end
end

--Terra function to get the variable values, given the variable ID: For variables with type int.
terra get_var_int(ncid: int, varid: int,  var_array_ptr: &int)
	var retval = netcdf.nc_get_var_int(ncid, varid, var_array_ptr)
    if retval == 1 then 
        cio.printf("Error extracting variable values of variable ID %d\n", varid)
    end
end

--Tera function to close file given NCID
terra file_close(ncid: int)
	var retval = netcdf.nc_close(ncid)
    if retval == 1 then 
        cio.printf("Error closing file of NCID %d \n", ncid)
    end
end

task main()
	var ncid : int

    -- Define the variable IDs
	var latCell_varid : int
	var lonCell_varid : int
	var indexToCellID_varid : int
    var cellsOnEdge_varid : int

    -- Define the data structures to store the variable values
	var latCell_in : double[nCells]
	var lonCell_in : double[nCells]
	var indexToCellID_in : int[nCells]
	var cellsOnEdge_in : int[nEdges][TWO]

    -- Open the file and store the NCID
	open_file(&ncid, FILE_NAME)

    -- Get the variable IDs of all the variables
	get_varid(ncid, "latCell", &latCell_varid)	
	get_varid(ncid, "lonCell", &lonCell_varid)
	get_varid(ncid, "indexToCellID", &indexToCellID_varid)
	get_varid(ncid, "cellsOnEdge", &cellsOnEdge_varid)
	
    -- Get the variable values, given the variable IDs (To add: error checking)
	get_var_double(ncid, latCell_varid, &latCell_in[0])
	get_var_double(ncid, lonCell_varid, &lonCell_in[0])
    get_var_int(ncid, lonCell_varid, &indexToCellID_in[0])
    get_var_int(ncid, cellsOnEdge_varid, &cellsOnEdge_in[0][0])

    -- Define region for cell latitude and longitude
    var is = ispace(ptr, nCells)
	var x_i_region = region(is, x_i)

    -- Copy data from array into region
    var i = 0
    for elem in x_i_region do
        -- elem is a ptr(x_i, x_i_region) (i.e. a pointer to a x_i field space in the x_i region)
        elem.lat = latCell_in[i]
        elem.lon = lonCell_in[i]
        i = i+1
        cio.printf("Loop %d: Lat is %f, Lon is %f\n", i, elem.lat, elem.lon)
    end

    -- Close the file
	file_close(ncid)
	
end
regentlib.start(main)
