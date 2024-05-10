//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <ailia/ailia_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) ailia_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "AiliaPlugin");
  ailia_plugin_register_with_registrar(ailia_registrar);
}
