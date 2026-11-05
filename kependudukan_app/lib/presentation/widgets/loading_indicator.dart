import 'package:flutter/material.dart';
import 'package:ladimas/core/theme/app_theme.dart';

class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
      ),
    );
  }
}
