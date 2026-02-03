part of 'package:drivererpapp/screens/module/common/tab_settings_screen.dart';

mixin _TabSettingsSaveMixin on State<TabSettingsScreen> {
  void _save() {
    final data = _collectData();
    if (widget.onSave != null) {
      widget.onSave!(data);
      Navigator.of(context).pop(data);
      return;
    }

    Navigator.of(context).pop(data);
  }

  Map<String, dynamic> _collectData() {
    return {
      'enableFilters': (this as _TabSettingsScreenState)._filtersEnabled,
      'filters': (this as _TabSettingsScreenState)._filters,
      'load_sub_table_data_automatically': (this as _TabSettingsScreenState)._loadSubTableAutomatically,
      'listTemplate': ListTemplateConfig(
        template: (this as _TabSettingsScreenState)._selectedTemplate,
        titleKey: (this as _TabSettingsScreenState)._listUseConditionalTitle ? null : (this as _TabSettingsScreenState)._titleKey,
        titleLogic: (this as _TabSettingsScreenState)._listUseConditionalTitle && (this as _TabSettingsScreenState)._listTitleLogicCondition != null
          ? ConditionalLogic(
              conditionKey: (this as _TabSettingsScreenState)._listTitleLogicCondition!, 
              truthyKey: (this as _TabSettingsScreenState)._listTitleLogicTruthy ?? '', 
              falsyKey: (this as _TabSettingsScreenState)._listTitleLogicFalsy ?? ''
            ) 
          : null,
        subtitleKey: (this as _TabSettingsScreenState)._listUseConditionalSubtitle ? null : (this as _TabSettingsScreenState)._subtitleKey,
        subtitleLogic: (this as _TabSettingsScreenState)._listUseConditionalSubtitle && (this as _TabSettingsScreenState)._listSubtitleLogicCondition != null
          ? ConditionalLogic(
              conditionKey: (this as _TabSettingsScreenState)._listSubtitleLogicCondition!, 
              truthyKey: (this as _TabSettingsScreenState)._listSubtitleLogicTruthy ?? '', 
              falsyKey: (this as _TabSettingsScreenState)._listSubtitleLogicFalsy ?? ''
            )
          : null,
        trailingKey: (this as _TabSettingsScreenState)._listUseConditionalTrailing ? null : (this as _TabSettingsScreenState)._trailingKey,
        trailingLogic: (this as _TabSettingsScreenState)._listUseConditionalTrailing && (this as _TabSettingsScreenState)._listTrailingLogicCondition != null
          ? ConditionalLogic(
              conditionKey: (this as _TabSettingsScreenState)._listTrailingLogicCondition!, 
              truthyKey: (this as _TabSettingsScreenState)._listTrailingLogicTruthy ?? '', 
              falsyKey: (this as _TabSettingsScreenState)._listTrailingLogicFalsy ?? ''
            )
          : null,
        detailKeys: (this as _TabSettingsScreenState)._detailKeys,
      ),
      'detailTemplate': DetailTemplateConfig(
        template: (this as _TabSettingsScreenState)._selectedDetailTemplate,
        titleKey: (this as _TabSettingsScreenState)._useConditionalTitle ? null : (this as _TabSettingsScreenState)._detailTitleKey,
        titleLogic: (this as _TabSettingsScreenState)._useConditionalTitle && (this as _TabSettingsScreenState)._titleLogicCondition != null 
          ? ConditionalLogic(
              conditionKey: (this as _TabSettingsScreenState)._titleLogicCondition!, 
              truthyKey: (this as _TabSettingsScreenState)._titleLogicTruthy ?? '', 
              falsyKey: (this as _TabSettingsScreenState)._titleLogicFalsy ?? ''
            ) 
          : null,
        subtitleKey: (this as _TabSettingsScreenState)._useConditionalSubtitle ? null : (this as _TabSettingsScreenState)._detailSubtitleKey,
        subtitleLogic: (this as _TabSettingsScreenState)._useConditionalSubtitle && (this as _TabSettingsScreenState)._subtitleLogicCondition != null
          ? ConditionalLogic(
              conditionKey: (this as _TabSettingsScreenState)._subtitleLogicCondition!, 
              truthyKey: (this as _TabSettingsScreenState)._subtitleLogicTruthy ?? '', 
              falsyKey: (this as _TabSettingsScreenState)._subtitleLogicFalsy ?? ''
            )
          : null,
        imageKey: (this as _TabSettingsScreenState)._detailImageKey,
        showAllFields: (this as _TabSettingsScreenState)._detailShowAll,
        detailKeys: (this as _TabSettingsScreenState)._detailFields,
      ),
    };
  }
}
