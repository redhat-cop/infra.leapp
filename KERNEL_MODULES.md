This is a helper script used to get the list of kernel modules that can
be used for testing the remediate_removed_kernel_drivers.  To use it,
get a system and install leapp - whatever package provides the file
/etc/leapp/files/device_driver_deprecation_data.json
The script will look for modules mentioned in the file, then will see
if the module can be loaded and unloaded.  The file loadable.N will
contain the list, where N is the major version of the OS.  For example,
if you run on a rhel 8 system, the file loadable.8 will contain the list
of modules that can be used for testing ipu 8 to 9 remediation.
Run it like this: `python script.py /etc/leapp/files/device_driver_deprecation_data.json`

```python
import json
import sys
from subprocess import check_call, CalledProcessError

data_file = sys.argv[1]  # e.g. /etc/leapp/files/device_driver_deprecation_data.json
with open(data_file) as fp:
    data_raw = json.load(fp)
drivers = [i for i in data_raw["data"] if i.get("driver_name")]

def no_next(i, key, src_maj):
    return src_maj in i.get(key) and src_maj+1 not in i.get(key)

# causes problems trying to load and unload
problems = set(["siw"])
for ver in range(7, 10):
    print("IPU {}, {}".format(ver, ver+1))
    print("deprecated")
    deprecated = sorted([i["driver_name"] for i in drivers if no_next(i, "maintained_in_rhel", ver)])
    print(deprecated)
    print("removed")
    removed = sorted([i["driver_name"] for i in drivers if no_next(i, "available_in_rhel", ver)])
    print(removed)
    # see which ones are loadable for testing
    loadable = set()
    notloadable = set()
    for driver in removed:
        if driver in problems:
            continue
        print("Trying " + driver)
        try:
            check_call(["modprobe", driver])
            check_call(["rmmod", driver])
            print("   loadable " + driver)
            loadable.add(driver)
        except CalledProcessError:
            print("   not loadable " + driver)
            notloadable.add(driver)
    with open("loadable." + str(ver), "w") as ll:
        ll.write("\n".join(list(loadable)))
    with open("notloadable." + str(ver), "w") as ll:
        ll.write("\n".join(list(notloadable)))
```
