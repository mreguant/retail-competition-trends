####################################
# Install the required packages
####################################

### create a function to install those packages that are not installed

install_packages = function(req_pkg, ins_pkg) 
    for p in req_pkg 
        if !in(p,ins_pkg) 
            Pkg.add(p)
        end 
    end
end

### comprehensive list of all required packages to run the full code

required_packages = [
    "CSV", "DataFrames", "StringEncodings","Dates", "Statistics", "TimeZones",
    "StatFiles","ShiftedArrays", "Plots", "FixedEffectModels", "CategoricalArrays", "RegressionTables"
]

### check which packages are already installed

# deprecated, but fastest version to check installed packages
using Pkg
installed_packages = keys(Pkg.installed())

# not deprecated, but slowest version
# installed_packages = [collect(values(Pkg.dependencies()))[p].name for p in 1:length(Pkg.dependencies())]

install_packages(required_packages, installed_packages)

println("\n
The list of required packages has been successfully installed.")
